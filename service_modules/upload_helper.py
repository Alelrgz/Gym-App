"""
Upload Helper - Unified file upload for all routes.
Uses Cloudinary in production, local filesystem in development.
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
MAX_IMAGE_SIZE = 5 * 1024 * 1024   # 5MB
MAX_DOC_SIZE = 10 * 1024 * 1024    # 10MB


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
    Save a file to Cloudinary (production) or local disk (dev).
    Returns the URL/path to the saved file.
    """
    if _is_cloudinary_ready():
        return _upload_cloudinary(content, folder, filename, upload_type)
    else:
        return _save_local(content, folder, filename)


def _upload_cloudinary(content: bytes, folder: str, filename: str, upload_type: str) -> str:
    """Upload to Cloudinary and return the secure URL."""
    import cloudinary.uploader

    name_without_ext = os.path.splitext(filename)[0]
    ext = os.path.splitext(filename)[1].lower()
    resource_type = "raw" if ext == ".pdf" else "image"

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
    """Delete a file from Cloudinary or local disk."""
    if not url:
        return False

    if "cloudinary.com" in url:
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
