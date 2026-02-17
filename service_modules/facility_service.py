"""
Facility Service - handles activity types, facilities, availability, and booking.
"""
from .base import (
    HTTPException, json, logging, date, datetime, timedelta,
    get_db_session, uuid
)
from models_orm import (
    ActivityTypeORM, FacilityORM, FacilityAvailabilityORM, FacilityBookingORM,
    UserORM, ClientProfileORM, ClientScheduleORM, NotificationORM
)

logger = logging.getLogger("gym_app")


class FacilityService:
    """Service for managing facilities and bookings."""

    # ==================== ACTIVITY TYPES ====================

    def get_activity_types(self, gym_id: str) -> list:
        from sqlalchemy import func
        db = get_db_session()
        try:
            types = db.query(ActivityTypeORM).filter(
                ActivityTypeORM.gym_id == gym_id,
                ActivityTypeORM.is_active == True
            ).order_by(ActivityTypeORM.sort_order, ActivityTypeORM.name).all()

            # Get facility counts per activity type
            counts = dict(
                db.query(FacilityORM.activity_type_id, func.count(FacilityORM.id))
                .filter(FacilityORM.is_active == True)
                .group_by(FacilityORM.activity_type_id)
                .all()
            )

            result = []
            for t in types:
                d = self._activity_type_to_dict(t)
                d["facility_count"] = counts.get(t.id, 0)
                result.append(d)
            return result
        finally:
            db.close()

    def create_activity_type(self, gym_id: str, data: dict) -> dict:
        db = get_db_session()
        try:
            new_type = ActivityTypeORM(
                id=str(uuid.uuid4()),
                gym_id=gym_id,
                name=data["name"],
                emoji=data.get("emoji"),
                description=data.get("description"),
                sort_order=data.get("sort_order", 0)
            )
            db.add(new_type)
            db.commit()
            db.refresh(new_type)
            return self._activity_type_to_dict(new_type)
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    def update_activity_type(self, type_id: str, gym_id: str, data: dict) -> dict:
        db = get_db_session()
        try:
            t = db.query(ActivityTypeORM).filter(
                ActivityTypeORM.id == type_id,
                ActivityTypeORM.gym_id == gym_id
            ).first()
            if not t:
                raise HTTPException(status_code=404, detail="Activity type not found")

            if "name" in data:
                t.name = data["name"]
            if "emoji" in data:
                t.emoji = data["emoji"]
            if "description" in data:
                t.description = data["description"]
            if "sort_order" in data:
                t.sort_order = data["sort_order"]

            t.updated_at = datetime.utcnow().isoformat()
            db.commit()
            db.refresh(t)
            return self._activity_type_to_dict(t)
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    def delete_activity_type(self, type_id: str, gym_id: str) -> dict:
        db = get_db_session()
        try:
            t = db.query(ActivityTypeORM).filter(
                ActivityTypeORM.id == type_id,
                ActivityTypeORM.gym_id == gym_id
            ).first()
            if not t:
                raise HTTPException(status_code=404, detail="Activity type not found")

            t.is_active = False
            t.updated_at = datetime.utcnow().isoformat()
            db.commit()
            return {"status": "success", "message": "Activity type deleted"}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    # ==================== FACILITIES ====================

    def get_facilities(self, activity_type_id: str) -> list:
        from sqlalchemy import func
        db = get_db_session()
        try:
            facilities = db.query(FacilityORM).filter(
                FacilityORM.activity_type_id == activity_type_id,
                FacilityORM.is_active == True
            ).order_by(FacilityORM.name).all()

            # Get availability day counts per facility
            avail_counts = dict(
                db.query(FacilityAvailabilityORM.facility_id, func.count(FacilityAvailabilityORM.id))
                .filter(FacilityAvailabilityORM.is_available == True)
                .group_by(FacilityAvailabilityORM.facility_id)
                .all()
            )

            result = []
            for f in facilities:
                d = self._facility_to_dict(f)
                d["availability_days"] = avail_counts.get(f.id, 0)
                result.append(d)
            return result
        finally:
            db.close()

    def create_facility(self, gym_id: str, data: dict) -> dict:
        db = get_db_session()
        try:
            # Verify activity type belongs to this gym
            at = db.query(ActivityTypeORM).filter(
                ActivityTypeORM.id == data["activity_type_id"],
                ActivityTypeORM.gym_id == gym_id
            ).first()
            if not at:
                raise HTTPException(status_code=404, detail="Activity type not found")

            facility = FacilityORM(
                id=str(uuid.uuid4()),
                activity_type_id=data["activity_type_id"],
                gym_id=gym_id,
                name=data["name"],
                description=data.get("description"),
                slot_duration=data.get("slot_duration", 60),
                price_per_slot=data.get("price_per_slot"),
                max_participants=data.get("max_participants")
            )
            db.add(facility)
            db.commit()
            db.refresh(facility)
            return self._facility_to_dict(facility)
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    def update_facility(self, facility_id: str, gym_id: str, data: dict) -> dict:
        db = get_db_session()
        try:
            f = db.query(FacilityORM).filter(
                FacilityORM.id == facility_id,
                FacilityORM.gym_id == gym_id
            ).first()
            if not f:
                raise HTTPException(status_code=404, detail="Facility not found")

            for key in ["name", "description", "slot_duration", "price_per_slot", "max_participants"]:
                if key in data:
                    setattr(f, key, data[key])

            f.updated_at = datetime.utcnow().isoformat()
            db.commit()
            db.refresh(f)
            return self._facility_to_dict(f)
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    def delete_facility(self, facility_id: str, gym_id: str) -> dict:
        db = get_db_session()
        try:
            f = db.query(FacilityORM).filter(
                FacilityORM.id == facility_id,
                FacilityORM.gym_id == gym_id
            ).first()
            if not f:
                raise HTTPException(status_code=404, detail="Facility not found")

            f.is_active = False
            f.updated_at = datetime.utcnow().isoformat()
            db.commit()
            return {"status": "success", "message": "Facility deleted"}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    # ==================== AVAILABILITY ====================

    def set_facility_availability(self, facility_id: str, gym_id: str, availability: list) -> dict:
        """Replace-all pattern: clear existing, insert new."""
        db = get_db_session()
        try:
            # Verify facility belongs to gym
            f = db.query(FacilityORM).filter(
                FacilityORM.id == facility_id,
                FacilityORM.gym_id == gym_id
            ).first()
            if not f:
                raise HTTPException(status_code=404, detail="Facility not found")

            # Clear existing
            db.query(FacilityAvailabilityORM).filter(
                FacilityAvailabilityORM.facility_id == facility_id
            ).delete()

            # Insert new
            for slot in availability:
                db.add(FacilityAvailabilityORM(
                    facility_id=facility_id,
                    day_of_week=slot["day_of_week"],
                    start_time=slot["start_time"],
                    end_time=slot["end_time"],
                    is_available=True
                ))

            db.commit()
            return {"status": "success", "message": "Availability updated"}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    def get_facility_availability(self, facility_id: str) -> list:
        db = get_db_session()
        try:
            slots = db.query(FacilityAvailabilityORM).filter(
                FacilityAvailabilityORM.facility_id == facility_id
            ).order_by(
                FacilityAvailabilityORM.day_of_week,
                FacilityAvailabilityORM.start_time
            ).all()
            return [{
                "id": s.id,
                "facility_id": s.facility_id,
                "day_of_week": s.day_of_week,
                "start_time": s.start_time,
                "end_time": s.end_time,
                "is_available": s.is_available
            } for s in slots]
        finally:
            db.close()

    # ==================== AVAILABLE SLOTS ====================

    def get_available_slots(self, facility_id: str, date_str: str) -> list:
        """Generate available time slots for a facility on a date."""
        db = get_db_session()
        try:
            # Get facility for slot_duration
            facility = db.query(FacilityORM).filter(
                FacilityORM.id == facility_id,
                FacilityORM.is_active == True
            ).first()
            if not facility:
                raise HTTPException(status_code=404, detail="Facility not found")

            slot_minutes = facility.slot_duration or 60

            target_date = datetime.fromisoformat(date_str)
            day_of_week = target_date.weekday()

            # Get availability for this day
            availability = db.query(FacilityAvailabilityORM).filter(
                FacilityAvailabilityORM.facility_id == facility_id,
                FacilityAvailabilityORM.day_of_week == day_of_week,
                FacilityAvailabilityORM.is_available == True
            ).all()

            if not availability:
                return []

            # Get existing bookings
            bookings = db.query(FacilityBookingORM).filter(
                FacilityBookingORM.facility_id == facility_id,
                FacilityBookingORM.date == date_str,
                FacilityBookingORM.status.in_(["confirmed"])
            ).all()

            available_slots = []
            now = datetime.now()

            for avail_block in availability:
                start_h, start_m = map(int, avail_block.start_time.split(':'))
                end_h, end_m = map(int, avail_block.end_time.split(':'))

                current = datetime.combine(target_date.date(), datetime.min.time().replace(hour=start_h, minute=start_m))
                block_end = datetime.combine(target_date.date(), datetime.min.time().replace(hour=end_h, minute=end_m))

                while current + timedelta(minutes=slot_minutes) <= block_end:
                    slot_end = current + timedelta(minutes=slot_minutes)

                    # Skip past slots
                    if target_date.date() == now.date() and current <= now:
                        current = slot_end
                        continue

                    # Check conflicts with bookings
                    is_booked = False
                    for b in bookings:
                        b_start_h, b_start_m = map(int, b.start_time.split(':'))
                        b_start = datetime.combine(target_date.date(), datetime.min.time().replace(hour=b_start_h, minute=b_start_m))
                        b_end = b_start + timedelta(minutes=b.duration)

                        if not (slot_end <= b_start or current >= b_end):
                            is_booked = True
                            break

                    if not is_booked:
                        available_slots.append({
                            "start_time": current.strftime("%H:%M"),
                            "end_time": slot_end.strftime("%H:%M"),
                            "available": True
                        })

                    current = slot_end

            return available_slots
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error getting facility slots: {e}")
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    # ==================== BOOKING ====================

    def book_facility(self, client_id: str, data: dict) -> dict:
        db = get_db_session()
        try:
            facility_id = data["facility_id"]
            booking_date = data["date"]
            start_time = data["start_time"]

            # Verify date not in past
            if datetime.fromisoformat(booking_date).date() < date.today():
                raise HTTPException(status_code=400, detail="Cannot book in the past")

            # Get facility
            facility = db.query(FacilityORM).filter(
                FacilityORM.id == facility_id,
                FacilityORM.is_active == True
            ).first()
            if not facility:
                raise HTTPException(status_code=404, detail="Facility not found")

            # Get activity type name
            activity_type = db.query(ActivityTypeORM).filter(
                ActivityTypeORM.id == facility.activity_type_id
            ).first()
            activity_name = activity_type.name if activity_type else "Activity"

            # Check slot availability
            available = self.get_available_slots(facility_id, booking_date)
            if not any(s["start_time"] == start_time for s in available):
                raise HTTPException(status_code=400, detail="This time slot is not available")

            duration = data.get("duration") or facility.slot_duration or 60
            start_parts = start_time.split(":")
            start_dt = datetime.combine(
                datetime.fromisoformat(booking_date).date(),
                datetime.min.time().replace(hour=int(start_parts[0]), minute=int(start_parts[1]))
            )
            end_time = (start_dt + timedelta(minutes=duration)).strftime("%H:%M")

            # Get client info
            client = db.query(UserORM).filter(UserORM.id == client_id).first()
            client_name = client.username if client else "Client"

            booking_id = str(uuid.uuid4())
            title = f"{activity_name} - {facility.name}"

            booking = FacilityBookingORM(
                id=booking_id,
                facility_id=facility_id,
                activity_type_id=facility.activity_type_id,
                gym_id=facility.gym_id,
                client_id=client_id,
                date=booking_date,
                start_time=start_time,
                end_time=end_time,
                duration=duration,
                title=title,
                notes=data.get("notes"),
                price=facility.price_per_slot,
                payment_method=data.get("payment_method"),
                payment_status="free" if not facility.price_per_slot else "pending",
                status="confirmed"
            )
            db.add(booking)

            # Add to client calendar
            time_12hr = start_dt.strftime("%I:%M %p")
            client_entry = ClientScheduleORM(
                client_id=client_id,
                date=booking_date,
                title=title,
                type="facility_booking",
                completed=False
            )
            db.add(client_entry)

            # Notify gym owner
            notification = NotificationORM(
                user_id=facility.gym_id,
                type="facility_booked",
                title="New Facility Booking",
                message=f"{client_name} booked {title} on {booking_date} at {time_12hr}",
                data=json.dumps({
                    "booking_id": booking_id,
                    "facility_id": facility_id,
                    "client_name": client_name,
                    "date": booking_date,
                    "time": time_12hr
                }),
                read=False,
                created_at=datetime.utcnow().isoformat()
            )
            db.add(notification)

            db.commit()
            logger.info(f"Facility booked: {booking_id} by {client_id}")

            return {
                "status": "success",
                "booking_id": booking_id,
                "title": title,
                "price": facility.price_per_slot,
                "message": "Booking confirmed"
            }
        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error booking facility: {e}")
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    def get_client_bookings(self, client_id: str, include_past: bool = False) -> list:
        db = get_db_session()
        try:
            query = db.query(FacilityBookingORM).filter(
                FacilityBookingORM.client_id == client_id
            )
            if not include_past:
                today = date.today().isoformat()
                query = query.filter(FacilityBookingORM.date >= today)

            bookings = query.order_by(FacilityBookingORM.date, FacilityBookingORM.start_time).all()

            result = []
            for b in bookings:
                facility = db.query(FacilityORM).filter(FacilityORM.id == b.facility_id).first()
                activity_type = db.query(ActivityTypeORM).filter(ActivityTypeORM.id == b.activity_type_id).first()
                result.append({
                    **self._booking_to_dict(b),
                    "facility_name": facility.name if facility else "",
                    "activity_name": activity_type.name if activity_type else "",
                    "activity_emoji": activity_type.emoji if activity_type else ""
                })
            return result
        finally:
            db.close()

    def get_facility_bookings(self, gym_id: str, date_from: str = None, date_to: str = None) -> list:
        db = get_db_session()
        try:
            query = db.query(FacilityBookingORM).filter(
                FacilityBookingORM.gym_id == gym_id
            )
            if date_from:
                query = query.filter(FacilityBookingORM.date >= date_from)
            if date_to:
                query = query.filter(FacilityBookingORM.date <= date_to)

            bookings = query.order_by(FacilityBookingORM.date, FacilityBookingORM.start_time).all()

            result = []
            for b in bookings:
                facility = db.query(FacilityORM).filter(FacilityORM.id == b.facility_id).first()
                client = db.query(UserORM).filter(UserORM.id == b.client_id).first()
                result.append({
                    **self._booking_to_dict(b),
                    "facility_name": facility.name if facility else "",
                    "client_name": client.username if client else ""
                })
            return result
        finally:
            db.close()

    def cancel_booking(self, booking_id: str, user_id: str, reason: str = None) -> dict:
        db = get_db_session()
        try:
            b = db.query(FacilityBookingORM).filter(
                FacilityBookingORM.id == booking_id
            ).first()
            if not b:
                raise HTTPException(status_code=404, detail="Booking not found")

            # Allow client or gym owner to cancel
            if b.client_id != user_id and b.gym_id != user_id:
                raise HTTPException(status_code=403, detail="Not authorized to cancel this booking")

            b.status = "canceled"
            b.canceled_by = user_id
            b.canceled_at = datetime.utcnow().isoformat()
            b.cancellation_reason = reason
            b.updated_at = datetime.utcnow().isoformat()
            db.commit()

            return {"status": "success", "message": "Booking canceled"}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    # ==================== CLIENT-FACING ====================

    def get_gym_activity_types(self, client_id: str) -> list:
        """Get activity types for the client's gym."""
        db = get_db_session()
        try:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if not profile or not profile.gym_id:
                return []

            types = db.query(ActivityTypeORM).filter(
                ActivityTypeORM.gym_id == profile.gym_id,
                ActivityTypeORM.is_active == True
            ).order_by(ActivityTypeORM.sort_order, ActivityTypeORM.name).all()

            result = []
            for t in types:
                td = self._activity_type_to_dict(t)
                # Count active facilities
                count = db.query(FacilityORM).filter(
                    FacilityORM.activity_type_id == t.id,
                    FacilityORM.is_active == True
                ).count()
                td["facility_count"] = count
                result.append(td)
            return result
        finally:
            db.close()

    def get_facilities_for_client(self, activity_type_id: str) -> list:
        """Get active facilities for an activity type."""
        db = get_db_session()
        try:
            facilities = db.query(FacilityORM).filter(
                FacilityORM.activity_type_id == activity_type_id,
                FacilityORM.is_active == True
            ).order_by(FacilityORM.name).all()
            return [self._facility_to_dict(f) for f in facilities]
        finally:
            db.close()

    # ==================== HELPERS ====================

    def _activity_type_to_dict(self, t: ActivityTypeORM) -> dict:
        return {
            "id": t.id,
            "gym_id": t.gym_id,
            "name": t.name,
            "emoji": t.emoji,
            "description": t.description,
            "is_active": t.is_active,
            "sort_order": t.sort_order,
            "created_at": t.created_at
        }

    def _facility_to_dict(self, f: FacilityORM) -> dict:
        return {
            "id": f.id,
            "activity_type_id": f.activity_type_id,
            "gym_id": f.gym_id,
            "name": f.name,
            "description": f.description,
            "slot_duration": f.slot_duration,
            "price_per_slot": f.price_per_slot,
            "max_participants": f.max_participants,
            "is_active": f.is_active,
            "created_at": f.created_at
        }

    def _booking_to_dict(self, b: FacilityBookingORM) -> dict:
        return {
            "id": b.id,
            "facility_id": b.facility_id,
            "activity_type_id": b.activity_type_id,
            "client_id": b.client_id,
            "date": b.date,
            "start_time": b.start_time,
            "end_time": b.end_time,
            "duration": b.duration,
            "title": b.title,
            "notes": b.notes,
            "price": b.price,
            "status": b.status,
            "created_at": b.created_at
        }


# Singleton pattern
_facility_service = None

def get_facility_service() -> FacilityService:
    global _facility_service
    if _facility_service is None:
        _facility_service = FacilityService()
    return _facility_service
