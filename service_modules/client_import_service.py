"""
Client Import Service - handles CSV parsing and bulk client creation.
"""
import csv
import io
import uuid
import string
import secrets
import logging

from database import get_db_session
from models_orm import UserORM, ClientProfileORM
from simple_auth import hash_password

logger = logging.getLogger("gym_app")

# Column aliases for flexible CSV header matching (includes Italian)
COLUMN_ALIASES = {
    'name': ['name', 'full_name', 'client_name', 'nome'],
    'email': ['email', 'e-mail', 'email_address', 'mail'],
    'phone': ['phone', 'phone_number', 'tel', 'telefono'],
    'weight': ['weight', 'weight_kg', 'peso'],
    'body_fat_pct': ['body_fat', 'body_fat_pct', 'bf', 'body_fat_percentage'],
    'height_cm': ['height', 'height_cm', 'altezza'],
    'date_of_birth': ['date_of_birth', 'dob', 'birth_date', 'data_nascita'],
    'gender': ['gender', 'sex', 'sesso'],
    'plan': ['plan', 'membership', 'piano'],
}


def _generate_temp_password(length=12):
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def _generate_username_from_name(name, suffix_len=4):
    parts = name.strip().lower().split()
    base = '_'.join(parts) if parts else 'client'
    base = ''.join(c for c in base if c.isalnum() or c == '_')
    suffix = ''.join(secrets.choice(string.ascii_lowercase + string.digits)
                     for _ in range(suffix_len))
    return f"{base}_{suffix}"


def _map_headers(raw_headers):
    mapping = {}
    for header in raw_headers:
        normalized = header.strip().lower().replace(' ', '_')
        for field, aliases in COLUMN_ALIASES.items():
            if normalized in aliases:
                mapping[field] = header
                break
    return mapping


def _parse_float(value):
    if not value or not value.strip():
        return None
    try:
        return float(value.strip().replace(',', '.'))
    except (ValueError, TypeError):
        return None


class ClientImportService:

    def process_csv(self, csv_content, owner_id):
        result = {
            "created": 0,
            "skipped": 0,
            "errors": [],
            "created_clients": []
        }

        # Decode CSV
        try:
            text = csv_content.decode('utf-8-sig')
        except UnicodeDecodeError:
            try:
                text = csv_content.decode('latin-1')
            except UnicodeDecodeError:
                result["errors"].append({"row": 0, "reason": "Could not decode file. Please use UTF-8 encoding."})
                return result

        # Auto-detect delimiter (comma, semicolon, tab)
        first_line = text.split('\n')[0] if text.strip() else ''
        if ';' in first_line and ',' not in first_line:
            delimiter = ';'
        elif '\t' in first_line and ',' not in first_line:
            delimiter = '\t'
        else:
            delimiter = ','

        reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
        if not reader.fieldnames:
            result["errors"].append({"row": 0, "reason": "CSV file appears to be empty or has no headers."})
            return result

        header_map = _map_headers(reader.fieldnames)

        if 'name' not in header_map and 'email' not in header_map:
            result["errors"].append({
                "row": 0,
                "reason": f"CSV must have at least a 'name' or 'email' column. Found: {', '.join(reader.fieldnames)}"
            })
            return result

        db = get_db_session()
        try:
            for row_num, row in enumerate(reader, start=2):
                try:
                    self._process_row(row, row_num, header_map, owner_id, db, result)
                except Exception as e:
                    logger.error(f"Import row {row_num} error: {e}")
                    result["errors"].append({"row": row_num, "reason": str(e)})

            db.commit()
        except Exception as e:
            db.rollback()
            logger.error(f"Import commit error: {e}")
            result["errors"].append({"row": 0, "reason": f"Database error: {str(e)}"})
        finally:
            db.close()

        return result

    def _process_row(self, row, row_num, header_map, owner_id, db, result):
        name = row.get(header_map.get('name', ''), '').strip() if 'name' in header_map else ''
        email = row.get(header_map.get('email', ''), '').strip() if 'email' in header_map else ''

        if not name and not email:
            result["errors"].append({"row": row_num, "reason": "Missing both name and email"})
            return

        # Check duplicate email
        if email:
            existing = db.query(UserORM).filter(UserORM.email == email).first()
            if existing:
                result["skipped"] += 1
                result["errors"].append({"row": row_num, "reason": f"Email already exists: {email}"})
                return

        # Determine username from name (e.g. "Gianni Arancione" -> "gianni_arancione")
        base_name = name if name else (email.split('@')[0] if email else 'client')
        username = ''.join(c for c in base_name.strip().lower().replace(' ', '_') if c.isalnum() or c == '_')
        if not username:
            username = 'client'

        # If taken, append a short suffix
        existing_user = db.query(UserORM).filter(UserORM.username == username).first()
        if existing_user:
            username = _generate_username_from_name(base_name, suffix_len=4)

        temp_password = _generate_temp_password()

        # Extract optional fields
        phone = row.get(header_map.get('phone', ''), '').strip() if 'phone' in header_map else None
        weight = _parse_float(row.get(header_map.get('weight', ''), '')) if 'weight' in header_map else None
        body_fat = _parse_float(row.get(header_map.get('body_fat_pct', ''), '')) if 'body_fat_pct' in header_map else None
        height = _parse_float(row.get(header_map.get('height_cm', ''), '')) if 'height_cm' in header_map else None
        dob = row.get(header_map.get('date_of_birth', ''), '').strip() if 'date_of_birth' in header_map else None
        gender = row.get(header_map.get('gender', ''), '').strip().lower() if 'gender' in header_map else None
        plan = row.get(header_map.get('plan', ''), '').strip() if 'plan' in header_map else 'Standard'

        if gender and gender not in ('male', 'female', 'other'):
            gender = None
        if not plan:
            plan = 'Standard'

        # Create user
        user_id = str(uuid.uuid4())
        user = UserORM(
            id=user_id,
            username=username,
            email=email if email else None,
            hashed_password=hash_password(temp_password),
            role="client",
            gym_owner_id=owner_id,
            is_approved=True,
            must_change_password=True,
            phone=phone if phone else None,
        )
        db.add(user)

        # Create profile
        display_name = name if name else (email.split('@')[0] if email else username)
        profile = ClientProfileORM(
            id=user_id,
            name=display_name,
            email=email if email else None,
            gym_id=owner_id,
            streak=0,
            gems=0,
            health_score=0,
            plan=plan,
            status="Active",
            last_seen="Never",
            is_premium=False,
            weight=weight,
            body_fat_pct=body_fat,
            height_cm=height,
            gender=gender,
        )
        if dob:
            profile.date_of_birth = dob
        db.add(profile)

        db.flush()

        result["created"] += 1
        result["created_clients"].append({
            "name": display_name,
            "email": email or "N/A",
            "username": username,
            "temp_password": temp_password
        })


client_import_service = ClientImportService()

def get_client_import_service():
    return client_import_service
