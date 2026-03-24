"""
Client Import Service - Smart CSV import with auto-detection of source platform.
Supports: Golee, BookyWay, Gymdesk, Virtuagym, Zen Planner, SportRick, Asso360, generic CSV.
"""
import csv
import io
import uuid
import string
import secrets
import logging
from datetime import datetime

from database import get_db_session
from models_orm import UserORM, ClientProfileORM, MedicalCertificateORM, ClientSubscriptionORM
from simple_auth import hash_password

logger = logging.getLogger("gym_app")

# ═══════════════════════════════════════════════════════════
#  PLATFORM SIGNATURES - header patterns to detect source
# ═══════════════════════════════════════════════════════════
PLATFORM_SIGNATURES = {
    'golee': {
        'markers': ['tesserato', 'codice fiscale', 'gruppo', 'quota'],
        'name': 'Golee',
    },
    'bookyway': {
        'markers': ['crediti', 'prenotazioni', 'abbonamento', 'bookyway'],
        'name': 'BookyWay',
    },
    'gymdesk': {
        'markers': ['member type', 'join date', 'check-in code', 'promotion date'],
        'name': 'Gymdesk',
    },
    'virtuagym': {
        'markers': ['member_id', 'membership_start', 'club_id', 'virtuagym'],
        'name': 'Virtuagym',
    },
    'zenplanner': {
        'markers': ['signup date', 'member status', 'zen planner'],
        'name': 'Zen Planner',
    },
    'sportrick': {
        'markers': ['sportrick', 'tessera', 'impianto'],
        'name': 'SportRick',
    },
    'asso360': {
        'markers': ['asso360', 'socio', 'numero tessera'],
        'name': 'Asso360',
    },
}

# ═══════════════════════════════════════════════════════════
#  COLUMN ALIASES - comprehensive mapping for all platforms
# ═══════════════════════════════════════════════════════════
COLUMN_ALIASES = {
    # Name fields
    'name': ['name', 'full_name', 'client_name', 'nome', 'nome completo',
             'tesserato', 'socio', 'member', 'member_name', 'nome e cognome',
             'nominativo'],
    'first_name': ['first_name', 'first name', 'nome', 'firstname', 'given_name'],
    'last_name': ['last_name', 'last name', 'cognome', 'lastname', 'surname', 'family_name'],
    # Contact
    'email': ['email', 'e-mail', 'email_address', 'mail', 'indirizzo email',
              'posta elettronica', 'primary_email', 'primary email'],
    'phone': ['phone', 'phone_number', 'tel', 'telefono', 'cellulare', 'mobile',
              'primary_phone', 'primary phone', 'cell', 'numero telefono'],
    # Body
    'weight': ['weight', 'weight_kg', 'peso', 'peso_kg'],
    'body_fat_pct': ['body_fat', 'body_fat_pct', 'bf', 'body_fat_percentage',
                     'percentuale grasso', 'massa grassa'],
    'height_cm': ['height', 'height_cm', 'altezza', 'statura'],
    # Personal
    'date_of_birth': ['date_of_birth', 'dob', 'birth_date', 'data_nascita',
                      'data di nascita', 'nato il', 'birthdate'],
    'gender': ['gender', 'sex', 'sesso', 'genere'],
    'fiscal_code': ['codice_fiscale', 'codice fiscale', 'cf', 'fiscal_code',
                    'tax_id', 'tax id'],
    'address': ['address', 'indirizzo', 'full_address', 'via', 'street',
                'indirizzo completo'],
    'city': ['city', 'citta', 'città', 'comune', 'localita'],
    'zip_code': ['zip', 'zip_code', 'cap', 'postal_code', 'codice postale'],
    # Membership
    'plan': ['plan', 'membership', 'piano', 'abbonamento', 'tipo abbonamento',
             'membership_title', 'member type', 'tipo'],
    'join_date': ['join_date', 'signup_date', 'signup date', 'join date',
                  'data iscrizione', 'data_iscrizione', 'registration_date',
                  'data registrazione', 'data ingresso'],
    'expiry_date': ['expiry_date', 'expiry', 'expiration', 'scadenza',
                    'data scadenza', 'data_scadenza', 'end_date', 'membership_end',
                    'fine abbonamento'],
    # Medical
    'cert_expiry': ['cert_expiry', 'certificato_scadenza', 'scadenza certificato',
                    'medical_cert_expiry', 'scadenza certificato medico',
                    'visita medica', 'medical_expiry'],
    # Status
    'status': ['status', 'stato', 'member_status', 'active', 'attivo'],
    # Payment
    'amount_paid': ['amount', 'amount_paid', 'importo', 'quota', 'fee',
                    'payment_amount', 'importo pagato'],
    # Notes
    'notes': ['notes', 'note', 'observazioni', 'commenti', 'comments'],
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
    """Map CSV headers to normalized field names."""
    mapping = {}
    for header in raw_headers:
        normalized = header.strip().lower().replace(' ', '_')
        for field, aliases in COLUMN_ALIASES.items():
            normalized_aliases = [a.replace(' ', '_') for a in aliases]
            if normalized in normalized_aliases or header.strip().lower() in aliases:
                if field not in mapping:  # first match wins
                    mapping[field] = header
                break
    return mapping


def _detect_platform(raw_headers):
    """Detect which platform exported the CSV based on column headers."""
    headers_lower = [h.strip().lower() for h in raw_headers]
    all_headers = ' '.join(headers_lower)

    best_match = None
    best_score = 0

    for platform_id, config in PLATFORM_SIGNATURES.items():
        score = sum(1 for marker in config['markers'] if marker in all_headers)
        if score > best_score:
            best_score = score
            best_match = platform_id

    if best_score >= 1:
        return best_match, PLATFORM_SIGNATURES[best_match]['name']
    return 'generic', 'CSV Generico'


def _parse_float(value):
    if not value or not value.strip():
        return None
    try:
        return float(value.strip().replace(',', '.'))
    except (ValueError, TypeError):
        return None


def _parse_date(value):
    """Try to parse a date string in various formats."""
    if not value or not value.strip():
        return None
    value = value.strip()
    formats = [
        '%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y', '%d.%m.%Y',
        '%m/%d/%Y', '%Y/%m/%d', '%d %m %Y', '%d/%m/%y',
    ]
    for fmt in formats:
        try:
            return datetime.strptime(value, fmt).strftime('%Y-%m-%d')
        except ValueError:
            continue
    return value  # return as-is if no format matches


def _normalize_gender(value):
    if not value:
        return None
    v = value.strip().lower()
    if v in ('m', 'male', 'maschio', 'uomo', 'maschile'):
        return 'male'
    if v in ('f', 'female', 'femmina', 'donna', 'femminile'):
        return 'female'
    return 'other'


class ClientImportService:

    def process_csv(self, csv_content, owner_id):
        result = {
            "created": 0,
            "skipped": 0,
            "errors": [],
            "created_clients": [],
            "platform_detected": None,
            "fields_mapped": [],
            "fields_unmapped": [],
        }

        # Decode CSV
        try:
            text = csv_content.decode('utf-8-sig')
        except UnicodeDecodeError:
            try:
                text = csv_content.decode('latin-1')
            except UnicodeDecodeError:
                result["errors"].append({"row": 0, "reason": "Impossibile decodificare il file. Usa codifica UTF-8."})
                return result

        # Auto-detect delimiter
        first_line = text.split('\n')[0] if text.strip() else ''
        if ';' in first_line and ',' not in first_line:
            delimiter = ';'
        elif '\t' in first_line and ',' not in first_line:
            delimiter = '\t'
        else:
            delimiter = ','

        reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
        if not reader.fieldnames:
            result["errors"].append({"row": 0, "reason": "Il file CSV sembra vuoto o senza intestazioni."})
            return result

        # Detect source platform
        platform_id, platform_name = _detect_platform(reader.fieldnames)
        result["platform_detected"] = platform_name
        logger.info(f"Import: detected platform '{platform_name}' from headers: {reader.fieldnames}")

        # Map headers
        header_map = _map_headers(reader.fieldnames)

        # Handle first_name + last_name -> name
        if 'name' not in header_map and ('first_name' in header_map or 'last_name' in header_map):
            header_map['_has_split_name'] = True

        result["fields_mapped"] = list(header_map.keys())
        result["fields_unmapped"] = [h for h in reader.fieldnames
                                      if h not in header_map.values()]

        if 'name' not in header_map and 'email' not in header_map and '_has_split_name' not in header_map:
            result["errors"].append({
                "row": 0,
                "reason": f"Il CSV deve avere almeno una colonna 'nome' o 'email'. Trovate: {', '.join(reader.fieldnames)}"
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
            result["errors"].append({"row": 0, "reason": f"Errore database: {str(e)}"})
        finally:
            db.close()

        return result

    def _process_row(self, row, row_num, header_map, owner_id, db, result):
        # Build full name from first_name + last_name if needed
        if header_map.get('_has_split_name'):
            first = row.get(header_map.get('first_name', ''), '').strip() if 'first_name' in header_map else ''
            last = row.get(header_map.get('last_name', ''), '').strip() if 'last_name' in header_map else ''
            name = f"{first} {last}".strip()
        else:
            name = row.get(header_map.get('name', ''), '').strip() if 'name' in header_map else ''

        email = row.get(header_map.get('email', ''), '').strip() if 'email' in header_map else ''

        if not name and not email:
            result["errors"].append({"row": row_num, "reason": "Nome e email mancanti"})
            return

        # Check duplicate email
        if email:
            existing = db.query(UserORM).filter(UserORM.email == email).first()
            if existing:
                result["skipped"] += 1
                result["errors"].append({"row": row_num, "reason": f"Email già esistente: {email}"})
                return

        # Generate username
        base_name = name if name else (email.split('@')[0] if email else 'client')
        username = ''.join(c for c in base_name.strip().lower().replace(' ', '_') if c.isalnum() or c == '_')
        if not username:
            username = 'client'

        existing_user = db.query(UserORM).filter(UserORM.username == username).first()
        if existing_user:
            username = _generate_username_from_name(base_name, suffix_len=4)

        temp_password = _generate_temp_password()

        # Extract all optional fields
        phone = row.get(header_map.get('phone', ''), '').strip() if 'phone' in header_map else None
        weight = _parse_float(row.get(header_map.get('weight', ''), '')) if 'weight' in header_map else None
        body_fat = _parse_float(row.get(header_map.get('body_fat_pct', ''), '')) if 'body_fat_pct' in header_map else None
        height = _parse_float(row.get(header_map.get('height_cm', ''), '')) if 'height_cm' in header_map else None
        dob = _parse_date(row.get(header_map.get('date_of_birth', ''), '')) if 'date_of_birth' in header_map else None
        gender = _normalize_gender(row.get(header_map.get('gender', ''), '')) if 'gender' in header_map else None
        plan = row.get(header_map.get('plan', ''), '').strip() if 'plan' in header_map else 'Standard'
        fiscal_code = row.get(header_map.get('fiscal_code', ''), '').strip() if 'fiscal_code' in header_map else None
        address = row.get(header_map.get('address', ''), '').strip() if 'address' in header_map else None
        city = row.get(header_map.get('city', ''), '').strip() if 'city' in header_map else None
        zip_code = row.get(header_map.get('zip_code', ''), '').strip() if 'zip_code' in header_map else None
        join_date = _parse_date(row.get(header_map.get('join_date', ''), '')) if 'join_date' in header_map else None
        expiry_date = _parse_date(row.get(header_map.get('expiry_date', ''), '')) if 'expiry_date' in header_map else None
        cert_expiry = _parse_date(row.get(header_map.get('cert_expiry', ''), '')) if 'cert_expiry' in header_map else None
        notes = row.get(header_map.get('notes', ''), '').strip() if 'notes' in header_map else None

        if not plan:
            plan = 'Standard'

        # Full address
        full_address = None
        parts = [p for p in [address, city, zip_code] if p]
        if parts:
            full_address = ', '.join(parts)

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
        if full_address:
            profile.address = full_address
        if fiscal_code:
            profile.fiscal_code = fiscal_code
        if notes:
            profile.notes = notes
        if join_date:
            profile.join_date = join_date
        db.add(profile)

        # Create medical certificate placeholder if cert_expiry provided
        if cert_expiry:
            cert = MedicalCertificateORM(
                user_id=user_id,
                gym_owner_id=owner_id,
                expiration_date=cert_expiry,
                approval_status="approved",
                uploaded_at=datetime.utcnow().isoformat(),
            )
            db.add(cert)

        db.flush()

        result["created"] += 1
        result["created_clients"].append({
            "name": display_name,
            "email": email or "N/A",
            "phone": phone or "",
            "username": username,
            "temp_password": temp_password,
            "plan": plan,
            "cert_expiry": cert_expiry,
        })


client_import_service = ClientImportService()

def get_client_import_service():
    return client_import_service
