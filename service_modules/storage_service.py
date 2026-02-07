"""
Storage Service for FitOS
Handles file uploads to Cloudinary (production) or local filesystem (development)
"""
import os
import uuid
from typing import Optional, Tuple
from datetime import datetime

# Try to import cloudinary
try:
    import cloudinary
    import cloudinary.uploader
    CLOUDINARY_AVAILABLE = True
except ImportError:
    CLOUDINARY_AVAILABLE = False


def _configure_cloudinary() -> bool:
    """Configure Cloudinary from environment variables. Returns True if configured."""
    cloud_name = os.environ.get("CLOUDINARY_CLOUD_NAME")
    api_key = os.environ.get("CLOUDINARY_API_KEY")
    api_secret = os.environ.get("CLOUDINARY_API_SECRET")

    if not all([cloud_name, api_key, api_secret]):
        return False

    if CLOUDINARY_AVAILABLE:
        cloudinary.config(
            cloud_name=cloud_name,
            api_key=api_key,
            api_secret=api_secret,
            secure=True
        )
        return True
    return False


def _is_cloudinary_enabled() -> bool:
    """Check if Cloudinary is available and configured."""
    return CLOUDINARY_AVAILABLE and _configure_cloudinary()


def _get_folder_for_type(upload_type: str) -> str:
    """Get the Cloudinary folder based on upload type."""
    folders = {
        "profile": "fitos/profiles",
        "certificate": "fitos/certificates",
        "document": "fitos/documents",
        "general": "fitos/uploads"
    }
    return folders.get(upload_type, "fitos/uploads")


def _get_local_path_for_type(upload_type: str) -> str:
    """Get the local folder path based on upload type."""
    base_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "uploads")
    paths = {
        "profile": os.path.join(base_path, "profiles"),
        "certificate": os.path.join(base_path, "certificates"),
        "document": os.path.join(base_path, "documents"),
        "general": base_path
    }
    return paths.get(upload_type, base_path)


async def upload_file(
    file_content: bytes,
    filename: str,
    upload_type: str = "general",
    user_id: Optional[int] = None
) -> Tuple[bool, str, Optional[str]]:
    """
    Upload a file to storage (Cloudinary or local).

    Args:
        file_content: The file bytes
        filename: Original filename
        upload_type: Type of upload (profile, certificate, document, general)
        user_id: Optional user ID for organizing files

    Returns:
        Tuple of (success, url_or_error_message, public_id_or_none)
    """
    # Generate unique filename
    ext = os.path.splitext(filename)[1].lower()
    unique_name = f"{uuid.uuid4().hex}{ext}"

    if _is_cloudinary_enabled():
        return await _upload_to_cloudinary(file_content, unique_name, upload_type, user_id)
    else:
        return await _upload_to_local(file_content, unique_name, upload_type)


async def _upload_to_cloudinary(
    file_content: bytes,
    filename: str,
    upload_type: str,
    user_id: Optional[int]
) -> Tuple[bool, str, Optional[str]]:
    """Upload file to Cloudinary."""
    try:
        folder = _get_folder_for_type(upload_type)
        if user_id:
            folder = f"{folder}/{user_id}"

        # Determine resource type based on file extension
        ext = os.path.splitext(filename)[1].lower()
        resource_type = "raw" if ext == ".pdf" else "image"

        # Upload to Cloudinary
        result = cloudinary.uploader.upload(
            file_content,
            folder=folder,
            public_id=os.path.splitext(filename)[0],
            resource_type=resource_type,
            overwrite=True
        )

        return True, result["secure_url"], result["public_id"]

    except Exception as e:
        return False, f"Cloudinary upload failed: {str(e)}", None


async def _upload_to_local(
    file_content: bytes,
    filename: str,
    upload_type: str
) -> Tuple[bool, str, Optional[str]]:
    """Upload file to local filesystem (fallback for development)."""
    try:
        local_path = _get_local_path_for_type(upload_type)
        os.makedirs(local_path, exist_ok=True)

        file_path = os.path.join(local_path, filename)
        with open(file_path, "wb") as f:
            f.write(file_content)

        # Return relative URL for local files
        relative_path = file_path.replace("\\", "/")
        if "static/" in relative_path:
            relative_path = "/" + relative_path.split("static/", 1)[1]
            relative_path = "/static" + relative_path

        return True, relative_path, None

    except Exception as e:
        return False, f"Local upload failed: {str(e)}", None


async def delete_file(url_or_public_id: str) -> bool:
    """
    Delete a file from storage.

    Args:
        url_or_public_id: Either the Cloudinary public_id or the local file URL

    Returns:
        True if deletion was successful
    """
    if _is_cloudinary_enabled() and "cloudinary" in url_or_public_id:
        try:
            # Extract public_id from URL if needed
            public_id = url_or_public_id
            if "cloudinary.com" in url_or_public_id:
                # Parse public_id from URL
                parts = url_or_public_id.split("/upload/")
                if len(parts) > 1:
                    public_id = parts[1].rsplit(".", 1)[0]
                    # Remove version if present (v1234567890/)
                    if public_id.startswith("v") and "/" in public_id:
                        public_id = public_id.split("/", 1)[1]

            cloudinary.uploader.destroy(public_id)
            return True
        except Exception:
            return False
    else:
        # Local file deletion
        try:
            if url_or_public_id.startswith("/static"):
                base_path = os.path.dirname(os.path.dirname(__file__))
                file_path = os.path.join(base_path, url_or_public_id.lstrip("/"))
                if os.path.exists(file_path):
                    os.remove(file_path)
                    return True
            return False
        except Exception:
            return False


def get_storage_info() -> dict:
    """Get information about current storage configuration."""
    cloudinary_configured = _is_cloudinary_enabled()
    return {
        "provider": "cloudinary" if cloudinary_configured else "local",
        "cloudinary_available": CLOUDINARY_AVAILABLE,
        "cloudinary_configured": cloudinary_configured,
        "local_path": _get_local_path_for_type("general")
    }
