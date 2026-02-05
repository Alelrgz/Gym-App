"""
Profile Routes - API endpoints for user profile management including profile pictures.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from auth import get_current_user
from models_orm import UserORM, PhysiquePhotoORM, ClientProfileORM, MedicalCertificateORM
from database import get_db_session
import os
import uuid
import traceback
from datetime import datetime
from typing import Optional

router = APIRouter(tags=["Profile"])

# Allowed image types
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp', 'gif'}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB

def allowed_file(filename: str) -> bool:
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@router.post("/api/profile/picture")
async def upload_profile_picture(
    file: UploadFile = File(...),
    user: UserORM = Depends(get_current_user)
):
    """Upload or update user's profile picture."""

    # Validate file type
    if not file.filename or not allowed_file(file.filename):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
        )

    # Read file content
    content = await file.read()

    # Validate file size
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum size: {MAX_FILE_SIZE // (1024*1024)}MB"
        )

    # Get file extension
    ext = file.filename.rsplit('.', 1)[1].lower()
    if ext == 'jpeg':
        ext = 'jpg'

    # Generate filename using user ID
    filename = f"{user.id}.{ext}"

    # Ensure uploads directory exists
    uploads_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'static', 'uploads', 'profiles')
    os.makedirs(uploads_dir, exist_ok=True)

    # Delete old profile picture if exists (different extension)
    for old_ext in ALLOWED_EXTENSIONS:
        old_file = os.path.join(uploads_dir, f"{user.id}.{old_ext}")
        if os.path.exists(old_file) and old_file != os.path.join(uploads_dir, filename):
            try:
                os.remove(old_file)
            except:
                pass

    # Save file
    file_path = os.path.join(uploads_dir, filename)

    # Try to resize/optimize with Pillow if available
    try:
        from PIL import Image
        import io

        img = Image.open(io.BytesIO(content))

        # Convert to RGB if necessary (for PNG with transparency)
        if img.mode in ('RGBA', 'P'):
            img = img.convert('RGB')
            ext = 'jpg'
            filename = f"{user.id}.{ext}"
            file_path = os.path.join(uploads_dir, filename)

        # Resize to max 400x400 while maintaining aspect ratio
        max_size = (400, 400)
        img.thumbnail(max_size, Image.Resampling.LANCZOS)

        # Center crop to square
        width, height = img.size
        min_dim = min(width, height)
        left = (width - min_dim) // 2
        top = (height - min_dim) // 2
        img = img.crop((left, top, left + min_dim, top + min_dim))

        # Save optimized
        img.save(file_path, quality=85, optimize=True)

    except ImportError:
        # Pillow not available, save raw
        with open(file_path, 'wb') as f:
            f.write(content)

    # Update database with relative path
    relative_path = f"/static/uploads/profiles/{filename}"

    db = get_db_session()
    try:
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            db_user.profile_picture = relative_path
            db.commit()
    finally:
        db.close()

    # Add cache-busting timestamp
    cache_bust = f"?t={int(datetime.now().timestamp())}"

    return {
        "success": True,
        "profile_picture": relative_path + cache_bust,
        "message": "Profile picture updated successfully"
    }


@router.delete("/api/profile/picture")
async def delete_profile_picture(user: UserORM = Depends(get_current_user)):
    """Delete user's profile picture."""

    uploads_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'static', 'uploads', 'profiles')

    # Delete all possible profile picture files for this user
    for ext in ALLOWED_EXTENSIONS:
        file_path = os.path.join(uploads_dir, f"{user.id}.{ext}")
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
            except:
                pass

    # Update database
    db = get_db_session()
    try:
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            db_user.profile_picture = None
            db.commit()
    finally:
        db.close()

    return {"success": True, "message": "Profile picture deleted"}


@router.get("/api/profile/picture")
async def get_profile_picture(user: UserORM = Depends(get_current_user)):
    """Get current user's profile picture URL."""
    return {
        "profile_picture": user.profile_picture,
        "username": user.username
    }


# ============ BIO ============

@router.get("/api/profile/bio")
async def get_bio(user: UserORM = Depends(get_current_user)):
    """Get current user's bio."""
    return {
        "bio": user.bio,
        "username": user.username
    }


@router.post("/api/profile/bio")
async def update_bio(
    user: UserORM = Depends(get_current_user),
    bio: str = Form(...)
):
    """Update user's bio (max 300 characters)."""
    # Validate bio length
    if len(bio) > 300:
        raise HTTPException(status_code=400, detail="Bio must be 300 characters or less")

    db = get_db_session()
    try:
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            db_user.bio = bio.strip() if bio.strip() else None
            db.commit()
            return {"success": True, "bio": db_user.bio, "message": "Bio updated successfully"}
        else:
            raise HTTPException(status_code=404, detail="User not found")
    finally:
        db.close()


# ============ SPECIALTIES ============

@router.get("/api/profile/specialties")
async def get_specialties(user: UserORM = Depends(get_current_user)):
    """Get current user's specialties."""
    specialties_list = []
    if user.specialties:
        specialties_list = [s.strip() for s in user.specialties.split(",") if s.strip()]
    return {
        "specialties": specialties_list,
        "username": user.username
    }


@router.post("/api/profile/specialties")
async def update_specialties(
    user: UserORM = Depends(get_current_user),
    specialties: str = Form(...)
):
    """Update user's specialties (comma-separated list)."""
    db = get_db_session()
    try:
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            # Clean and validate specialties
            specialties_cleaned = specialties.strip() if specialties.strip() else None
            db_user.specialties = specialties_cleaned
            db.commit()

            # Return as list for frontend
            specialties_list = []
            if specialties_cleaned:
                specialties_list = [s.strip() for s in specialties_cleaned.split(",") if s.strip()]

            return {"success": True, "specialties": specialties_list, "message": "Specialties updated successfully"}
        else:
            raise HTTPException(status_code=404, detail="User not found")
    finally:
        db.close()


# ============ PHYSIQUE PHOTOS ============
# Visible only to the client and their assigned trainer/nutritionist

MAX_PHYSIQUE_FILE_SIZE = 10 * 1024 * 1024  # 10MB for physique photos


def get_client_trainer_id(client_id: str, db) -> Optional[str]:
    """Get the trainer ID assigned to a client."""
    profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
    return profile.trainer_id if profile else None


def can_view_physique_photos(user: UserORM, client_id: str, db) -> bool:
    """Check if user can view physique photos for a client."""
    # Client can always view their own
    if str(user.id) == str(client_id):
        return True

    # Trainer/nutritionist can view their assigned clients
    if user.role in ['trainer', 'nutritionist', 'owner']:
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
        if profile and str(profile.trainer_id) == str(user.id):
            return True

    return False


@router.post("/api/physique/photo")
async def upload_physique_photo(
    file: UploadFile = File(...),
    title: Optional[str] = Form(None),
    photo_date: Optional[str] = Form(None),
    notes: Optional[str] = Form(None),
    user: UserORM = Depends(get_current_user)
):
    """Upload a new physique progress photo with metadata."""
    file_path = None
    db = None

    try:
        print(f"[PHYSIQUE] Starting upload for user {user.id}, file: {file.filename}")

        # Validate file type
        if not file.filename or not allowed_file(file.filename):
            raise HTTPException(
                status_code=400,
                detail=f"Invalid file type. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
            )

        # Read file content
        content = await file.read()
        print(f"[PHYSIQUE] Read {len(content)} bytes")

        # Validate file size
        if len(content) > MAX_PHYSIQUE_FILE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"File too large. Maximum size: {MAX_PHYSIQUE_FILE_SIZE // (1024*1024)}MB"
            )

        # Get file extension
        ext = file.filename.rsplit('.', 1)[1].lower()
        if ext == 'jpeg':
            ext = 'jpg'

        # Generate unique filename
        unique_id = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:8]}"
        filename = f"{unique_id}.{ext}"

        # Ensure uploads directory exists (organized by user)
        uploads_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'static', 'uploads', 'physique', str(user.id))
        os.makedirs(uploads_dir, exist_ok=True)
        print(f"[PHYSIQUE] Uploads dir: {uploads_dir}")

        file_path = os.path.join(uploads_dir, filename)

        # Try to resize/optimize with Pillow if available
        try:
            from PIL import Image
            import io

            print(f"[PHYSIQUE] Processing image with Pillow...")
            img = Image.open(io.BytesIO(content))

            # Convert to RGB if necessary
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
                ext = 'jpg'
                filename = f"{unique_id}.{ext}"
                file_path = os.path.join(uploads_dir, filename)

            # Resize to max 1200px while maintaining aspect ratio
            max_size = (1200, 1600)
            img.thumbnail(max_size, Image.Resampling.LANCZOS)

            # Save optimized
            print(f"[PHYSIQUE] Saving to: {file_path}")
            img.save(file_path, quality=85, optimize=True)
            print(f"[PHYSIQUE] Image saved successfully")

        except ImportError:
            # Pillow not available, save raw
            print(f"[PHYSIQUE] Pillow not available, saving raw")
            with open(file_path, 'wb') as f:
                f.write(content)
        except Exception as pil_error:
            print(f"[PHYSIQUE] PIL error: {pil_error}")
            traceback.print_exc()
            # Fallback to raw save
            with open(file_path, 'wb') as f:
                f.write(content)

        # Save to database
        print(f"[PHYSIQUE] Saving to database...")
        db = get_db_session()

        # Get trainer ID for this client
        trainer_id = get_client_trainer_id(str(user.id), db)
        print(f"[PHYSIQUE] Trainer ID: {trainer_id}")

        relative_path = f"/static/uploads/physique/{user.id}/{filename}"

        photo_record = PhysiquePhotoORM(
            client_id=str(user.id),
            trainer_id=trainer_id,
            title=title or "Progress Photo",
            photo_date=photo_date or datetime.now().strftime('%Y-%m-%d'),
            notes=notes,
            filename=filename,
            file_path=relative_path
        )
        db.add(photo_record)
        db.commit()
        db.refresh(photo_record)
        print(f"[PHYSIQUE] Saved to DB with ID: {photo_record.id}")

        cache_bust = f"?t={int(datetime.now().timestamp())}"

        return {
            "success": True,
            "photo_id": photo_record.id,
            "photo_url": relative_path + cache_bust,
            "title": photo_record.title,
            "photo_date": photo_record.photo_date,
            "notes": photo_record.notes,
            "message": "Physique photo uploaded"
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"[PHYSIQUE] UNEXPECTED ERROR: {e}")
        traceback.print_exc()
        # Clean up file if it was created
        if file_path and os.path.exists(file_path):
            try:
                os.remove(file_path)
            except:
                pass
        if db:
            db.rollback()
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")
    finally:
        if db:
            db.close()


@router.delete("/api/physique/photo/{photo_id}")
async def delete_physique_photo(
    photo_id: int,
    user: UserORM = Depends(get_current_user)
):
    """Delete a physique progress photo."""

    db = get_db_session()
    try:
        # Find the photo record
        photo = db.query(PhysiquePhotoORM).filter(PhysiquePhotoORM.id == photo_id).first()

        if not photo:
            raise HTTPException(status_code=404, detail="Photo not found")

        # Check permission - only client or their trainer can delete
        if str(photo.client_id) != str(user.id) and str(photo.trainer_id) != str(user.id):
            raise HTTPException(status_code=403, detail="Not authorized to delete this photo")

        # Delete file from disk
        full_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), photo.file_path.lstrip('/'))
        if os.path.exists(full_path):
            os.remove(full_path)

        # Delete from database
        db.delete(photo)
        db.commit()

        return {"success": True, "message": "Photo deleted"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete photo: {str(e)}")
    finally:
        db.close()


@router.get("/api/physique/photos")
async def get_physique_photos(
    client_id: Optional[str] = None,
    user: UserORM = Depends(get_current_user)
):
    """Get physique photos. Client sees their own, trainer sees their clients'."""

    db = get_db_session()
    try:
        # Determine which client's photos to fetch
        target_client_id = client_id or str(user.id)

        # Check permission
        if not can_view_physique_photos(user, target_client_id, db):
            raise HTTPException(status_code=403, detail="Not authorized to view these photos")

        # Get photos from database
        photos = db.query(PhysiquePhotoORM).filter(
            PhysiquePhotoORM.client_id == target_client_id
        ).order_by(PhysiquePhotoORM.photo_date.desc(), PhysiquePhotoORM.created_at.desc()).all()

        return {
            "photos": [
                {
                    "photo_id": p.id,
                    "photo_url": p.file_path,
                    "title": p.title,
                    "photo_date": p.photo_date,
                    "notes": p.notes,
                    "created_at": p.created_at
                }
                for p in photos
            ]
        }
    finally:
        db.close()


# ============ MEDICAL CERTIFICATES ============

CERT_ALLOWED_EXTENSIONS = {'pdf', 'png', 'jpg', 'jpeg'}
MAX_CERT_FILE_SIZE = 10 * 1024 * 1024  # 10MB


def allowed_cert_file(filename: str) -> bool:
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in CERT_ALLOWED_EXTENSIONS


def can_view_certificate(user: UserORM, client_id: str, db) -> bool:
    """Check if user can view a client's medical certificate."""
    if str(user.id) == str(client_id):
        return True
    if user.role == 'owner':
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
        if profile and str(profile.gym_id) == str(user.id):
            return True
    if user.role in ['trainer', 'nutritionist']:
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
        if profile and str(profile.trainer_id) == str(user.id):
            return True
    if user.role == 'staff':
        member = db.query(UserORM).filter(UserORM.id == client_id).first()
        if member and member.gym_owner_id and member.gym_owner_id == user.gym_owner_id:
            return True
    return False


@router.post("/api/medical/certificate")
async def upload_medical_certificate(
    file: UploadFile = File(...),
    expiration_date: Optional[str] = Form(None),
    user: UserORM = Depends(get_current_user)
):
    """Upload a medical certificate (certificato medico sportivo)."""
    if user.role != 'client':
        raise HTTPException(status_code=403, detail="Only clients can upload medical certificates")

    if not file.filename or not allowed_cert_file(file.filename):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(CERT_ALLOWED_EXTENSIONS)}"
        )

    content = await file.read()

    if len(content) > MAX_CERT_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum size: {MAX_CERT_FILE_SIZE // (1024*1024)}MB"
        )

    ext = file.filename.rsplit('.', 1)[1].lower()
    if ext == 'jpeg':
        ext = 'jpg'

    unique_id = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:8]}"
    filename = f"{unique_id}.{ext}"

    uploads_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'static', 'uploads', 'certificates', str(user.id))
    os.makedirs(uploads_dir, exist_ok=True)

    file_path = os.path.join(uploads_dir, filename)
    db = None

    try:
        # For images, optimize with Pillow
        if ext != 'pdf':
            try:
                from PIL import Image
                import io
                img = Image.open(io.BytesIO(content))
                if img.mode in ('RGBA', 'P'):
                    img = img.convert('RGB')
                    ext = 'jpg'
                    filename = f"{unique_id}.{ext}"
                    file_path = os.path.join(uploads_dir, filename)
                max_size = (1600, 2200)
                img.thumbnail(max_size, Image.Resampling.LANCZOS)
                img.save(file_path, quality=85, optimize=True)
            except ImportError:
                with open(file_path, 'wb') as f:
                    f.write(content)
        else:
            with open(file_path, 'wb') as f:
                f.write(content)

        relative_path = f"/static/uploads/certificates/{user.id}/{filename}"

        db = get_db_session()

        # Delete old certificate(s) for this client
        old_certs = db.query(MedicalCertificateORM).filter(
            MedicalCertificateORM.client_id == str(user.id)
        ).all()
        for old in old_certs:
            old_full_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), old.file_path.lstrip('/'))
            if os.path.exists(old_full_path):
                try:
                    os.remove(old_full_path)
                except:
                    pass
            db.delete(old)

        cert = MedicalCertificateORM(
            client_id=str(user.id),
            filename=file.filename,
            file_path=relative_path,
            expiration_date=expiration_date
        )
        db.add(cert)
        db.commit()
        db.refresh(cert)

        return {
            "success": True,
            "certificate": {
                "id": cert.id,
                "filename": cert.filename,
                "file_url": relative_path + f"?t={int(datetime.now().timestamp())}",
                "expiration_date": cert.expiration_date,
                "uploaded_at": cert.uploaded_at
            },
            "message": "Medical certificate uploaded"
        }

    except HTTPException:
        raise
    except Exception as e:
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
            except:
                pass
        if db:
            db.rollback()
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")
    finally:
        if db:
            db.close()


@router.get("/api/medical/certificate")
async def get_medical_certificate(
    client_id: Optional[str] = None,
    user: UserORM = Depends(get_current_user)
):
    """Get medical certificate. Client sees own, owner/trainer sees by client_id."""
    db = get_db_session()
    try:
        target_id = client_id or str(user.id)

        if not can_view_certificate(user, target_id, db):
            raise HTTPException(status_code=403, detail="Not authorized to view this certificate")

        cert = db.query(MedicalCertificateORM).filter(
            MedicalCertificateORM.client_id == target_id
        ).order_by(MedicalCertificateORM.id.desc()).first()

        if not cert:
            return {"certificate": None}

        # Calculate status based on expiration
        status = "valid"
        if cert.expiration_date:
            try:
                exp = datetime.strptime(cert.expiration_date, "%Y-%m-%d")
                days_left = (exp - datetime.now()).days
                if days_left < 0:
                    status = "expired"
                elif days_left <= 30:
                    status = "expiring"
            except ValueError:
                pass

        return {
            "certificate": {
                "id": cert.id,
                "filename": cert.filename,
                "file_url": cert.file_path,
                "expiration_date": cert.expiration_date,
                "uploaded_at": cert.uploaded_at,
                "status": status
            }
        }
    finally:
        db.close()


@router.delete("/api/medical/certificate/{cert_id}")
async def delete_medical_certificate(
    cert_id: int,
    user: UserORM = Depends(get_current_user)
):
    """Delete a medical certificate."""
    db = get_db_session()
    try:
        cert = db.query(MedicalCertificateORM).filter(MedicalCertificateORM.id == cert_id).first()
        if not cert:
            raise HTTPException(status_code=404, detail="Certificate not found")

        if str(cert.client_id) != str(user.id) and user.role != 'owner':
            raise HTTPException(status_code=403, detail="Not authorized to delete this certificate")

        full_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), cert.file_path.lstrip('/'))
        if os.path.exists(full_path):
            os.remove(full_path)

        db.delete(cert)
        db.commit()
        return {"success": True, "message": "Certificate deleted"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete: {str(e)}")
    finally:
        db.close()


@router.get("/api/medical/certificates/overview")
async def get_certificates_overview(
    user: UserORM = Depends(get_current_user)
):
    """Get certificate status for all clients in the gym (owner/trainer only)."""
    if user.role not in ['owner', 'trainer', 'staff']:
        raise HTTPException(status_code=403, detail="Not authorized")

    db = get_db_session()
    try:
        # Get all clients in this gym
        if user.role == 'owner':
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == str(user.id)
            ).all()
        elif user.role == 'staff':
            # Staff sees all clients in their gym
            gym_clients = db.query(UserORM).filter(
                UserORM.gym_owner_id == user.gym_owner_id,
                UserORM.role == 'client'
            ).all()
            client_ids = [c.id for c in gym_clients]
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.id.in_(client_ids)
            ).all() if client_ids else []
        else:
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.trainer_id == str(user.id)
            ).all()

        results = []
        for client in clients:
            cert = db.query(MedicalCertificateORM).filter(
                MedicalCertificateORM.client_id == client.id
            ).order_by(MedicalCertificateORM.id.desc()).first()

            client_user = db.query(UserORM).filter(UserORM.id == client.id).first()
            name = client.name or (client_user.username if client_user else "Unknown")

            status = "missing"
            expiration_date = None
            file_url = None
            if cert:
                file_url = cert.file_path
                expiration_date = cert.expiration_date
                status = "valid"
                if cert.expiration_date:
                    try:
                        exp = datetime.strptime(cert.expiration_date, "%Y-%m-%d")
                        days_left = (exp - datetime.now()).days
                        if days_left < 0:
                            status = "expired"
                        elif days_left <= 30:
                            status = "expiring"
                    except ValueError:
                        pass

            results.append({
                "client_id": client.id,
                "name": name,
                "status": status,
                "expiration_date": expiration_date,
                "file_url": file_url
            })

        # Sort: expired first, then expiring, then missing, then valid
        order = {"expired": 0, "expiring": 1, "missing": 2, "valid": 3}
        results.sort(key=lambda x: order.get(x["status"], 4))

        return {"clients": results}
    finally:
        db.close()
