"""
Diet Service - handles meal scanning, logging, and diet assignment.
"""
from .base import (
    HTTPException, json, logging, date, datetime,
    get_db_session, ClientDietSettingsORM, ClientDietLogORM
)
from models import AssignDietRequest

logger = logging.getLogger("gym_app")


class DietService:
    """Service for managing client diet, meal scanning, and logging."""

    def scan_meal(self, file_bytes: bytes) -> dict:
        """Scan a meal image using Gemini AI and return nutritional estimates."""
        import google.generativeai as genai
        import os
        import random

        api_key = os.environ.get("GEMINI_API_KEY")
        print(f"DEBUG: scan_meal called. API Key present: {bool(api_key)}")

        if not api_key:
            print("Warning: GEMINI_API_KEY not found, using mock.")
            # Mock AI Analysis Fallback
            foods = [
                {"name": "Grilled Chicken Salad", "cals": 450, "protein": 40, "carbs": 15, "fat": 20},
                {"name": "Avocado Toast", "cals": 350, "protein": 12, "carbs": 45, "fat": 18},
                {"name": "Protein Oatmeal", "cals": 380, "protein": 25, "carbs": 50, "fat": 6},
                {"name": "Salmon & Rice", "cals": 550, "protein": 35, "carbs": 60, "fat": 22},
                {"name": "Greek Yogurt Parfait", "cals": 280, "protein": 20, "carbs": 30, "fat": 5}
            ]
            result = random.choice(foods)
            return {"status": "success", "data": result}

        try:
            genai.configure(api_key=api_key)
            # Try Gemini 2.0 Flash Lite - often has better availability/quota
            model_name = 'gemini-2.0-flash-lite-preview-02-05'
            print(f"DEBUG: Initializing Gemini with model: {model_name}")
            model = genai.GenerativeModel(model_name)

            prompt = """
            Analyze this food image and estimate the nutritional content.
            Return ONLY a raw JSON object with these keys:
            - name: A short descriptive name of the meal
            - cals: Total calories (integer)
            - protein: Protein in grams (integer)
            - carbs: Carbs in grams (integer)
            - fat: Fat in grams (integer)

            Example: {"name": "Chicken Salad", "cals": 450, "protein": 40, "carbs": 10, "fat": 20}
            """

            response = model.generate_content([
                prompt,
                {
                    "mime_type": "image/jpeg",
                    "data": file_bytes
                }
            ])

            text = response.text
            # Clean up markdown code blocks if present
            if text.startswith("```json"):
                text = text[7:]
            elif text.startswith("```"):
                text = text[3:]
            if text.endswith("```"):
                text = text[:-3]

            data = json.loads(text.strip())

            return {
                "status": "success",
                "data": data
            }

        except Exception as e:
            print(f"Gemini Error: {e}")
            print("Falling back to mock data due to API error.")

            # Mock Data Fallback
            foods = [
                {"name": "Grilled Chicken Salad", "cals": 450, "protein": 40, "carbs": 15, "fat": 20},
                {"name": "Avocado Toast", "cals": 350, "protein": 12, "carbs": 45, "fat": 18},
                {"name": "Protein Oatmeal", "cals": 380, "protein": 25, "carbs": 50, "fat": 6},
                {"name": "Salmon & Rice", "cals": 550, "protein": 35, "carbs": 60, "fat": 22},
                {"name": "Greek Yogurt Parfait", "cals": 280, "protein": 20, "carbs": 30, "fat": 5}
            ]
            result = random.choice(foods)

            return {
                "status": "success",
                "data": result,
                "message": "⚠️ AI Quota Exceeded. Using simulated data."
            }

    def log_meal(self, client_id: str, meal_data: dict) -> dict:
        """Log a meal for a client and update their current macros."""
        db = get_db_session()
        try:
            log = ClientDietLogORM(
                client_id=client_id,
                date=date.today().isoformat(),
                meal_type=meal_data.get("meal_type", "Snack"),
                meal_name=meal_data.get("name"),
                calories=meal_data.get("cals"),
                time=datetime.now().strftime("%H:%M")
            )
            db.add(log)

            # Update current macros
            settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
            if settings:
                settings.calories_current += meal_data.get("cals", 0)
                settings.protein_current += meal_data.get("protein", 0)
                settings.carbs_current += meal_data.get("carbs", 0)
                settings.fat_current += meal_data.get("fat", 0)

            db.commit()
            return {"status": "success", "message": "Meal logged"}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to log meal: {str(e)}")
        finally:
            db.close()

    def update_client_diet(self, client_id: str, diet_data: dict) -> dict:
        """Update a client's diet settings (macros, hydration, consistency targets)."""
        db = get_db_session()
        try:
            settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
            if not settings:
                settings = ClientDietSettingsORM(id=client_id)
                db.add(settings)

            if "macros" in diet_data:
                macros = diet_data["macros"]
                if "calories" in macros: settings.calories_target = macros["calories"].get("target", settings.calories_target)
                if "protein" in macros: settings.protein_target = macros["protein"].get("target", settings.protein_target)
                if "carbs" in macros: settings.carbs_target = macros["carbs"].get("target", settings.carbs_target)
                if "fat" in macros: settings.fat_target = macros["fat"].get("target", settings.fat_target)

            if "hydration_target" in diet_data:
                settings.hydration_target = diet_data["hydration_target"]
            if "consistency_target" in diet_data:
                settings.consistency_target = diet_data["consistency_target"]

            db.commit()
            return {"status": "success"}
        finally:
            db.close()

    def assign_diet(self, diet_data: AssignDietRequest) -> dict:
        """Assign a complete diet plan to a client."""
        client_id = diet_data.client_id
        db = get_db_session()
        try:
            settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
            if not settings:
                settings = ClientDietSettingsORM(id=client_id)
                db.add(settings)

            settings.calories_target = diet_data.calories
            settings.protein_target = diet_data.protein
            settings.carbs_target = diet_data.carbs
            settings.fat_target = diet_data.fat
            settings.hydration_target = diet_data.hydration_target
            settings.consistency_target = diet_data.consistency_target

            db.commit()
            return {"status": "success"}
        finally:
            db.close()


# Singleton instance
diet_service = DietService()

def get_diet_service() -> DietService:
    """Dependency injection helper."""
    return diet_service
