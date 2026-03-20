"""
Upload Helper - Unified file upload for all routes.
Priority: Supabase Storage > Cloudinary > local filesystem.
"""
import os
import io
import uuid
import logging
from datetime import datetime
from typing import Tuple, Optional

logger = logging.getLogger("gym_app")

ALLOWED_IMAGE_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp', 'gif'}
ALLOWED_DOC_EXTENSIONS = {'pdf', 'png', 'jpg', 'jpeg'}
ALLOWED_VIDEO_EXTENSIONS = {'mp4', 'webm', 'mov', 'avi'}
ALLOWED_AUDIO_EXTENSIONS = {'webm', 'ogg', 'mp3', 'm4a', 'wav', 'opus'}
MAX_IMAGE_SIZE = 5 * 1024 * 1024    # 5MB
MAX_DOC_SIZE = 10 * 1024 * 1024     # 10MB
MAX_VIDEO_SIZE = 50 * 1024 * 1024   # 50MB (Supabase free tier limit)
MAX_AUDIO_SIZE = 20 * 1024 * 1024   # 20MB

# Supabase Storage config
_SUPABASE_URL = os.environ.get("SUPABASE_URL")
_SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

# Map folder names to Supabase buckets
_FOLDER_TO_BUCKET = {
    "profiles": "profiles",
    "certificates": "certificates",
    "physique": "physique",
    "exercise_videos": "videos",
    "chat_images": "chat-media",
    "chat_videos": "chat-media",
    "chat_audio": "chat-media",
    "community": "community",
}


def _is_supabase_ready() -> bool:
    """Check if Supabase Storage is configured."""
    return bool(_SUPABASE_URL and _SUPABASE_SERVICE_KEY)


def _is_cloudinary_ready() -> bool:
    """Check if Cloudinary is available and configured."""
    try:
        import cloudinary
        import cloudinary.uploader
        cloud_name = os.environ.get("CLOUDINARY_CLOUD_NAME")
        api_key = os.environ.get("CLOUDINARY_API_KEY")
        api_secret = os.environ.get("CLOUDINARY_API_SECRET")
        if all([cloud_name, api_key, api_secret]):
            cloudinary.config(
                cloud_name=cloud_name,
                api_key=api_key,
                api_secret=api_secret,
                secure=True
            )
            return True
    except ImportError:
        pass
    return False


def _optimize_image(content: bytes, max_size: tuple = (400, 400), crop_square: bool = False) -> Tuple[bytes, str]:
    """Optimize image with Pillow. Returns (bytes, extension)."""
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(content))

        if img.mode in ('RGBA', 'P'):
            img = img.convert('RGB')

        img.thumbnail(max_size, Image.Resampling.LANCZOS)

        if crop_square:
            w, h = img.size
            d = min(w, h)
            left = (w - d) // 2
            top = (h - d) // 2
            img = img.crop((left, top, left + d, top + d))

        buf = io.BytesIO()
        img.save(buf, format='JPEG', quality=85, optimize=True)
        return buf.getvalue(), 'jpg'
    except ImportError:
        return content, 'jpg'


async def save_file(
    content: bytes,
    folder: str,
    filename: str,
    upload_type: str = "image"
) -> str:
    """
    Save a file to Supabase Storage (preferred) > Cloudinary > local disk.
    Returns the URL/path to the saved file.
    """
    if _is_supabase_ready():
        return _upload_supabase(content, folder, filename)
    elif _is_cloudinary_ready():
        return _upload_cloudinary(content, folder, filename, upload_type)
    else:
        return _save_local(content, folder, filename)


def _upload_supabase(content: bytes, folder: str, filename: str) -> str:
    """Upload to Supabase Storage and return the public/signed URL."""
    import requests

    # Determine bucket from folder
    base_folder = folder.split("/")[0]
    bucket = _FOLDER_TO_BUCKET.get(base_folder, "profiles")

    # Build storage path (e.g., "user123/photo.jpg" within the bucket)
    storage_path = f"{folder}/{filename}"

    # Detect content type
    ext = os.path.splitext(filename)[1].lower().lstrip(".")
    content_types = {
        'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
        'webp': 'image/webp', 'gif': 'image/gif', 'pdf': 'application/pdf',
        'mp4': 'video/mp4', 'webm': 'video/webm', 'mov': 'video/quicktime',
        'mp3': 'audio/mpeg', 'ogg': 'audio/ogg', 'wav': 'audio/wav',
        'm4a': 'audio/mp4', 'opus': 'audio/opus',
    }
    content_type = content_types.get(ext, 'application/octet-stream')

    headers = {
        'Authorization': f'Bearer {_SUPABASE_SERVICE_KEY}',
        'apikey': _SUPABASE_SERVICE_KEY,
        'Content-Type': content_type,
        'x-upsert': 'true',
    }

    url = f"{_SUPABASE_URL}/storage/v1/object/{bucket}/{storage_path}"
    r = requests.post(url, headers=headers, data=content)

    if r.status_code not in (200, 201):
        logger.error(f"Supabase upload failed: {r.status_code} {r.text[:200]}")
        raise Exception(f"Supabase upload failed: {r.status_code}")

    # Return public URL for public buckets, signed URL for private
    public_url = f"{_SUPABASE_URL}/storage/v1/object/public/{bucket}/{storage_path}"
    logger.info(f"Supabase upload: {bucket}/{storage_path}")
    return public_url


def _upload_cloudinary(content: bytes, folder: str, filename: str, upload_type: str) -> str:
    """Upload to Cloudinary and return the secure URL."""
    import cloudinary.uploader

    name_without_ext = os.path.splitext(filename)[0]
    ext = os.path.splitext(filename)[1].lower().lstrip(".")
    if ext == "pdf":
        resource_type = "raw"
    elif ext in ALLOWED_VIDEO_EXTENSIONS or ext in ALLOWED_AUDIO_EXTENSIONS or upload_type in ("video", "voice", "audio"):
        resource_type = "video"  # Cloudinary uses "video" for both audio and video
    else:
        resource_type = "image"

    result = cloudinary.uploader.upload(
        content,
        folder=f"fitos/{folder}",
        public_id=name_without_ext,
        resource_type=resource_type,
        overwrite=True
    )
    logger.info(f"Cloudinary upload: fitos/{folder}/{filename}")
    return result["secure_url"]


def _save_local(content: bytes, folder: str, filename: str) -> str:
    """Save to local filesystem and return the relative URL."""
    base_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'static', 'uploads', folder)
    os.makedirs(base_dir, exist_ok=True)

    file_path = os.path.join(base_dir, filename)
    with open(file_path, 'wb') as f:
        f.write(content)

    return f"/static/uploads/{folder}/{filename}"


async def delete_file(url: str) -> bool:
    """Delete a file from Supabase, Cloudinary, or local disk."""
    if not url:
        return False

    if "supabase.co/storage" in url:
        try:
            import requests
            # Extract bucket and path from URL
            # URL format: https://xxx.supabase.co/storage/v1/object/public/{bucket}/{path}
            parts = url.split("/storage/v1/object/public/")
            if len(parts) < 2:
                parts = url.split("/storage/v1/object/")
            if len(parts) > 1:
                bucket_and_path = parts[1]
                bucket = bucket_and_path.split("/")[0]
                file_path = "/".join(bucket_and_path.split("/")[1:])

                headers = {
                    'Authorization': f'Bearer {_SUPABASE_SERVICE_KEY}',
                    'apikey': _SUPABASE_SERVICE_KEY,
                    'Content-Type': 'application/json',
                }
                r = requests.delete(
                    f"{_SUPABASE_URL}/storage/v1/object/{bucket}",
                    headers=headers,
                    json={"prefixes": [file_path]}
                )
                if r.status_code in (200, 204):
                    return True
                logger.error(f"Supabase delete failed: {r.status_code} {r.text[:200]}")
        except Exception as e:
            logger.error(f"Supabase delete failed: {e}")
        return False

    elif "cloudinary.com" in url:
        try:
            import cloudinary.uploader
            if _is_cloudinary_ready():
                # Extract public_id from URL
                parts = url.split("/upload/")
                if len(parts) > 1:
                    public_id = parts[1].rsplit(".", 1)[0]
                    if public_id.startswith("v") and "/" in public_id:
                        public_id = public_id.split("/", 1)[1]
                    cloudinary.uploader.destroy(public_id)
                    return True
        except Exception as e:
            logger.error(f"Cloudinary delete failed: {e}")
        return False
    else:
        # Local file
        try:
            if url.startswith("/static"):
                base_path = os.path.dirname(os.path.dirname(__file__))
                file_path = os.path.join(base_path, url.lstrip("/"))
                if os.path.exists(file_path):
                    os.remove(file_path)
                    return True
        except Exception as e:
            logger.error(f"Local delete failed: {e}")
        return False
