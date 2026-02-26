"""
Nutritionist Appointment Service - handles nutritionist availability and consultation booking.
Mirrors the trainer appointment service pattern.
"""
from .base import (
    HTTPException, json, logging, date, datetime,
    get_db_session, UserORM, ClientProfileORM, ClientScheduleORM, NotificationORM
)
from models_orm import NutritionistAvailabilityORM, NutritionistAppointmentORM
from models import (
    BookNutritionistAppointmentRequest,
    SetAvailabilityRequest, CancelAppointmentRequest
)
from typing import List
import uuid
from datetime import timedelta

logger = logging.getLogger("gym_app")


class NutritionistAppointmentService:
    """Service for managing nutritionist availability and appointment booking."""

    # --- AVAILABILITY ---

    def set_availability(self, nutritionist_id: str, availability: List[SetAvailabilityRequest]) -> dict:
        """Set or update nutritionist's weekly availability."""
        db = get_db_session()
        try:
            db.query(NutritionistAvailabilityORM).filter(
                NutritionistAvailabilityORM.nutritionist_id == nutritionist_id
            ).delete()

            for slot in availability:
                db.add(NutritionistAvailabilityORM(
                    nutritionist_id=nutritionist_id,
                    day_of_week=slot.day_of_week,
                    start_time=slot.start_time,
                    end_time=slot.end_time,
                    is_available=True
                ))

            db.commit()
            logger.info(f"Updated availability for nutritionist: {nutritionist_id}")
            return {"status": "success", "message": "Availability updated successfully"}

        except Exception as e:
            db.rollback()
            logger.error(f"Error setting nutritionist availability: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to set availability: {str(e)}")
        finally:
            db.close()

    def get_availability(self, nutritionist_id: str) -> List[dict]:
        """Get nutritionist's weekly availability schedule."""
        db = get_db_session()
        try:
            slots = db.query(NutritionistAvailabilityORM).filter(
                NutritionistAvailabilityORM.nutritionist_id == nutritionist_id
            ).order_by(NutritionistAvailabilityORM.day_of_week, NutritionistAvailabilityORM.start_time).all()

            return [
                {
                    "id": s.id,
                    "nutritionist_id": s.nutritionist_id,
                    "day_of_week": s.day_of_week,
                    "start_time": s.start_time,
                    "end_time": s.end_time,
                    "is_available": s.is_available
                }
                for s in slots
            ]
        finally:
            db.close()

    def get_available_slots(self, nutritionist_id: str, date_str: str) -> List[dict]:
        """Get available time slots for a specific nutritionist on a specific date."""
        db = get_db_session()
        try:
            target_date = datetime.fromisoformat(date_str)
            day_of_week = target_date.weekday()

            availability = db.query(NutritionistAvailabilityORM).filter(
                NutritionistAvailabilityORM.nutritionist_id == nutritionist_id,
                NutritionistAvailabilityORM.day_of_week == day_of_week,
                NutritionistAvailabilityORM.is_available == True
            ).all()

            if not availability:
                return []

            booked = db.query(NutritionistAppointmentORM).filter(
                NutritionistAppointmentORM.nutritionist_id == nutritionist_id,
                NutritionistAppointmentORM.date == date_str,
                NutritionistAppointmentORM.status.in_(["scheduled", "confirmed"])
            ).all()

            available_slots = []

            for avail_block in availability:
                start_hour, start_min = map(int, avail_block.start_time.split(':'))
                end_hour, end_min = map(int, avail_block.end_time.split(':'))

                start_time = datetime.combine(target_date.date(), datetime.min.time().replace(hour=start_hour, minute=start_min))
                end_time = datetime.combine(target_date.date(), datetime.min.time().replace(hour=end_hour, minute=end_min))

                current_time = start_time
                while current_time < end_time:
                    slot_end = current_time + timedelta(hours=1)
                    if slot_end > end_time:
                        break

                    is_booked = False
                    for appt in booked:
                        appt_start_h, appt_start_m = map(int, appt.start_time.split(':'))
                        appt_start = datetime.combine(target_date.date(), datetime.min.time().replace(hour=appt_start_h, minute=appt_start_m))
                        appt_end = appt_start + timedelta(minutes=appt.duration)

                        if not (slot_end <= appt_start or current_time >= appt_end):
                            is_booked = True
                            break

                    now = datetime.now()
                    if target_date.date() == now.date() and current_time <= now:
                        current_time = slot_end
                        continue

                    if not is_booked:
                        available_slots.append({
                            "start_time": current_time.strftime("%H:%M"),
                            "end_time": slot_end.strftime("%H:%M"),
                            "available": True
                        })

                    current_time = slot_end

            return available_slots

        except Exception as e:
            logger.error(f"Error getting available slots: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to get available slots: {str(e)}")
        finally:
            db.close()

    # --- BOOKING ---

    def book_appointment(self, client_id: str, request: BookNutritionistAppointmentRequest) -> dict:
        """Book a consultation with a nutritionist."""
        db = get_db_session()
        try:
            appointment_date = datetime.fromisoformat(request.date).date()
            if appointment_date < date.today():
                raise HTTPException(status_code=400, detail="Cannot book appointments in the past")

            nutritionist = db.query(UserORM).filter(UserORM.id == request.nutritionist_id).first()
            if not nutritionist:
                raise HTTPException(status_code=404, detail="Nutritionist not found")

            client = db.query(UserORM).filter(UserORM.id == client_id).first()
            client_name = client.username if client else "Client"

            available_slots = self.get_available_slots(request.nutritionist_id, request.date)
            slot_available = any(s["start_time"] == request.start_time for s in available_slots)
            if not slot_available:
                raise HTTPException(status_code=400, detail="This time slot is not available")

            # Calculate end time
            start_parts = request.start_time.split(":")
            start_dt = datetime.combine(
                datetime.fromisoformat(request.date).date(),
                datetime.min.time().replace(hour=int(start_parts[0]), minute=int(start_parts[1]))
            )
            end_dt = start_dt + timedelta(minutes=request.duration)
            end_time = end_dt.strftime("%H:%M")
            time_12hr = start_dt.strftime("%I:%M %p")

            # Calculate price
            session_price = None
            rate = getattr(nutritionist, 'session_rate', None)
            if rate and rate > 0:
                session_price = round(rate * (request.duration / 60), 2)

            payment_method = getattr(request, 'payment_method', None)
            payment_status = "free"
            if session_price and session_price > 0:
                if payment_method == "card":
                    payment_status = "paid"
                else:
                    payment_status = "pending"

            appointment_id = str(uuid.uuid4())
            session_type = request.session_type or "consultation"

            appt = NutritionistAppointmentORM(
                id=appointment_id,
                client_id=client_id,
                nutritionist_id=request.nutritionist_id,
                date=request.date,
                start_time=request.start_time,
                end_time=end_time,
                duration=request.duration,
                session_type=session_type,
                notes=request.notes,
                status="scheduled",
                price=session_price,
                payment_method=payment_method,
                payment_status=payment_status,
                stripe_payment_intent_id=getattr(request, 'stripe_payment_intent_id', None)
            )
            db.add(appt)

            # Client calendar entry
            session_label = session_type.replace("_", " ").title()
            nutri_name = nutritionist.username
            client_cal = ClientScheduleORM(
                client_id=client_id,
                date=request.date,
                title=f"{session_label} con {nutri_name}",
                type="nutrition_appointment",
                completed=False
            )
            db.add(client_cal)

            # Notification for nutritionist
            notification = NotificationORM(
                user_id=request.nutritionist_id,
                type="nutrition_appointment_booked",
                title="Nuovo Appuntamento",
                message=f"{client_name} ha prenotato una {session_label} il {request.date} alle {time_12hr}",
                data=json.dumps({
                    "appointment_id": appointment_id,
                    "client_id": client_id,
                    "client_name": client_name,
                    "date": request.date,
                    "time": time_12hr,
                    "duration": request.duration
                }),
                read=False,
                created_at=datetime.utcnow().isoformat()
            )
            db.add(notification)

            # Payment record
            if payment_method == "card" and session_price and session_price > 0:
                from models_orm import PaymentORM
                db.add(PaymentORM(
                    id=str(uuid.uuid4()),
                    client_id=client_id,
                    gym_id=nutritionist.gym_owner_id,
                    amount=session_price,
                    currency="eur",
                    status="succeeded",
                    stripe_payment_intent_id=getattr(request, 'stripe_payment_intent_id', None),
                    description=f"Consulenza Nutrizionale con {nutri_name}",
                    payment_method="card",
                    paid_at=datetime.utcnow().isoformat(),
                    created_at=datetime.utcnow().isoformat()
                ))

            db.commit()
            logger.info(f"Nutrition appointment booked: {appointment_id} - Client: {client_id}, Nutritionist: {request.nutritionist_id}")

            return {
                "status": "success",
                "appointment_id": appointment_id,
                "price": session_price,
                "payment_method": payment_method,
                "payment_status": payment_status,
                "message": "Appointment booked successfully"
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error booking nutrition appointment: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to book appointment: {str(e)}")
        finally:
            db.close()

    # --- LISTING ---

    def get_client_appointments(self, client_id: str, include_past: bool = False) -> List[dict]:
        """Get all nutrition appointments for a client."""
        db = get_db_session()
        try:
            query = db.query(NutritionistAppointmentORM, UserORM).join(
                UserORM, NutritionistAppointmentORM.nutritionist_id == UserORM.id
            ).filter(NutritionistAppointmentORM.client_id == client_id)

            if not include_past:
                today = datetime.now().date().isoformat()
                query = query.filter(NutritionistAppointmentORM.date >= today)

            appointments = query.order_by(NutritionistAppointmentORM.date, NutritionistAppointmentORM.start_time).all()

            return [
                {
                    "id": appt.id,
                    "nutritionist_id": appt.nutritionist_id,
                    "nutritionist_name": nutri.username,
                    "date": appt.date,
                    "start_time": appt.start_time,
                    "end_time": appt.end_time,
                    "duration": appt.duration,
                    "title": appt.title,
                    "notes": appt.notes,
                    "nutritionist_notes": appt.nutritionist_notes,
                    "status": appt.status,
                    "created_at": appt.created_at
                }
                for appt, nutri in appointments
            ]
        finally:
            db.close()

    def get_nutritionist_appointments(self, nutritionist_id: str, include_past: bool = False) -> List[dict]:
        """Get all appointments for a nutritionist."""
        db = get_db_session()
        try:
            query = db.query(NutritionistAppointmentORM, UserORM).join(
                UserORM, NutritionistAppointmentORM.client_id == UserORM.id
            ).filter(NutritionistAppointmentORM.nutritionist_id == nutritionist_id)

            if not include_past:
                today = datetime.now().date().isoformat()
                query = query.filter(NutritionistAppointmentORM.date >= today)

            appointments = query.order_by(NutritionistAppointmentORM.date, NutritionistAppointmentORM.start_time).all()

            return [
                {
                    "id": appt.id,
                    "client_id": appt.client_id,
                    "client_name": client.username,
                    "date": appt.date,
                    "start_time": appt.start_time,
                    "end_time": appt.end_time,
                    "duration": appt.duration,
                    "title": appt.title,
                    "notes": appt.notes,
                    "nutritionist_notes": appt.nutritionist_notes,
                    "status": appt.status,
                    "created_at": appt.created_at
                }
                for appt, client in appointments
            ]
        finally:
            db.close()

    # --- CANCEL / COMPLETE ---

    def cancel_appointment(self, appointment_id: str, user_id: str, request: CancelAppointmentRequest) -> dict:
        """Cancel a nutrition appointment."""
        db = get_db_session()
        try:
            appt = db.query(NutritionistAppointmentORM).filter(
                NutritionistAppointmentORM.id == appointment_id
            ).first()

            if not appt:
                raise HTTPException(status_code=404, detail="Appointment not found")
            if appt.client_id != user_id and appt.nutritionist_id != user_id:
                raise HTTPException(status_code=403, detail="You don't have permission to cancel this appointment")
            if appt.status == "canceled":
                raise HTTPException(status_code=400, detail="Appointment is already canceled")

            appt.status = "canceled"
            appt.canceled_by = user_id
            appt.canceled_at = datetime.utcnow().isoformat()
            appt.cancellation_reason = request.cancellation_reason
            appt.updated_at = datetime.utcnow().isoformat()

            # Remove from client calendar
            client_entries = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == appt.client_id,
                ClientScheduleORM.date == appt.date,
                ClientScheduleORM.type == "nutrition_appointment"
            ).all()
            for entry in client_entries:
                db.delete(entry)

            # Notify the other party
            notify_user = appt.nutritionist_id if user_id == appt.client_id else appt.client_id
            canceler = db.query(UserORM).filter(UserORM.id == user_id).first()
            db.add(NotificationORM(
                user_id=notify_user,
                type="nutrition_appointment_canceled",
                title="Appuntamento Annullato",
                message=f"{canceler.username if canceler else 'Utente'} ha annullato l'appuntamento del {appt.date}",
                data=json.dumps({"appointment_id": appointment_id}),
                read=False,
                created_at=datetime.utcnow().isoformat()
            ))

            db.commit()
            logger.info(f"Nutrition appointment canceled: {appointment_id} by {user_id}")
            return {"status": "success", "message": "Appointment canceled successfully"}

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error canceling nutrition appointment: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to cancel appointment: {str(e)}")
        finally:
            db.close()

    def complete_appointment(self, appointment_id: str, nutritionist_id: str, notes: str = None) -> dict:
        """Mark a nutrition appointment as completed."""
        db = get_db_session()
        try:
            appt = db.query(NutritionistAppointmentORM).filter(
                NutritionistAppointmentORM.id == appointment_id,
                NutritionistAppointmentORM.nutritionist_id == nutritionist_id
            ).first()

            if not appt:
                raise HTTPException(status_code=404, detail="Appointment not found")
            if appt.status == "completed":
                raise HTTPException(status_code=400, detail="Appointment is already completed")

            appt.status = "completed"
            appt.nutritionist_notes = notes
            appt.updated_at = datetime.utcnow().isoformat()

            db.commit()
            logger.info(f"Nutrition appointment completed: {appointment_id}")
            return {"status": "success", "message": "Appointment marked as completed"}

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error completing nutrition appointment: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to complete appointment: {str(e)}")
        finally:
            db.close()


# Singleton
nutritionist_appointment_service = NutritionistAppointmentService()


def get_nutritionist_appointment_service() -> NutritionistAppointmentService:
    return nutritionist_appointment_service
