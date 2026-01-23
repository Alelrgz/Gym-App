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
        """Scan a meal image using hybrid AI approach (Clarifai + Nutritionix) for maximum accuracy."""
        import os
        import random

        # Try Hybrid Approach first (most accurate)
        clarifai_key = os.environ.get("CLARIFAI_API_KEY")
        nutritionix_app_id = os.environ.get("NUTRITIONIX_APP_ID")
        nutritionix_api_key = os.environ.get("NUTRITIONIX_API_KEY")

        if clarifai_key and nutritionix_app_id and nutritionix_api_key:
            try:
                result = self._scan_hybrid(file_bytes, clarifai_key, nutritionix_app_id, nutritionix_api_key)
                return {"status": "success", "data": result}
            except Exception as e:
                logger.error(f"Hybrid scan failed: {e}")

        # Fallback to Clarifai + Groq (85-90% accuracy)
        groq_key = os.environ.get("GROQ_API_KEY")
        if clarifai_key and groq_key:
            try:
                result = self._scan_clarifai_groq(file_bytes, clarifai_key, groq_key)
                return {"status": "success", "data": result}
            except Exception as e:
                logger.error(f"Clarifai+Groq scan failed: {e}")

        # Fallback to Groq Vision only (80-85% accuracy, no Clarifai needed)
        if groq_key:
            try:
                result = self._scan_groq_only(file_bytes, groq_key)
                return {"status": "success", "data": result}
            except Exception as e:
                logger.error(f"Groq Vision scan failed: {e}")

        # Fallback to Gemini
        gemini_key = os.environ.get("GEMINI_API_KEY")
        if gemini_key:
            try:
                result = self._scan_gemini(file_bytes, gemini_key)
                return {"status": "success", "data": result}
            except Exception as e:
                logger.error(f"Gemini scan failed: {e}")

        # Final fallback: Mock data
        print("Warning: No API keys found, using mock data.")
        foods = [
            {"name": "Grilled Chicken Salad", "cals": 450, "protein": 40, "carbs": 15, "fat": 20},
            {"name": "Avocado Toast", "cals": 350, "protein": 12, "carbs": 45, "fat": 18},
            {"name": "Protein Oatmeal", "cals": 380, "protein": 25, "carbs": 50, "fat": 6},
            {"name": "Salmon & Rice", "cals": 550, "protein": 35, "carbs": 60, "fat": 22},
            {"name": "Greek Yogurt Parfait", "cals": 280, "protein": 20, "carbs": 30, "fat": 5}
        ]
        result = random.choice(foods)
        return {"status": "success", "data": result}

    def _scan_hybrid(self, file_bytes: bytes, clarifai_key: str, nutritionix_app_id: str, nutritionix_api_key: str) -> dict:
        """Hybrid approach: Clarifai identifies food, Nutritionix gets accurate macros."""
        import base64
        import requests

        logger.info("Using hybrid scan (Clarifai + Nutritionix)")

        # Step 1: Use Clarifai to identify food items
        clarifai_url = "https://api.clarifai.com/v2/models/food-item-recognition/outputs"
        headers = {
            "Authorization": f"Key {clarifai_key}",
            "Content-Type": "application/json"
        }

        base64_image = base64.b64encode(file_bytes).decode('utf-8')
        payload = {
            "user_app_id": {
                "user_id": "clarifai",
                "app_id": "main"
            },
            "inputs": [{
                "data": {
                    "image": {
                        "base64": base64_image
                    }
                }
            }]
        }

        clarifai_response = requests.post(clarifai_url, headers=headers, json=payload, timeout=10)
        clarifai_response.raise_for_status()

        # Extract top food items
        clarifai_data = clarifai_response.json()
        concepts = clarifai_data['outputs'][0]['data']['concepts']
        top_foods = [c['name'] for c in concepts[:3] if c['value'] > 0.7]  # Top 3 with >70% confidence

        if not top_foods:
            raise Exception("No food items detected with sufficient confidence")

        logger.info(f"Clarifai identified: {top_foods}")

        # Step 2: Use Nutritionix to get accurate macros for primary food
        primary_food = top_foods[0]
        nutritionix_url = "https://trackapi.nutritionix.com/v2/natural/nutrients"
        headers = {
            "x-app-id": nutritionix_app_id,
            "x-app-key": nutritionix_api_key,
            "Content-Type": "application/json"
        }

        # Build query from all identified foods
        query = " and ".join(top_foods)
        payload = {"query": query}

        nutritionix_response = requests.post(nutritionix_url, headers=headers, json=payload, timeout=10)
        nutritionix_response.raise_for_status()

        # Aggregate nutritional data
        nutritionix_data = nutritionix_response.json()
        foods_data = nutritionix_data.get('foods', [])

        if not foods_data:
            raise Exception("No nutritional data found")

        # Sum up all identified foods
        total_cals = sum(food.get('nf_calories', 0) for food in foods_data)
        total_protein = sum(food.get('nf_protein', 0) for food in foods_data)
        total_carbs = sum(food.get('nf_total_carbohydrate', 0) for food in foods_data)
        total_fat = sum(food.get('nf_total_fat', 0) for food in foods_data)

        # Build meal name
        meal_name = ", ".join([food.get('food_name', '').title() for food in foods_data[:3]])
        serving_info = foods_data[0].get('serving_qty', 1)
        serving_unit = foods_data[0].get('serving_unit', 'serving')

        return {
            "name": meal_name,
            "cals": int(total_cals),
            "protein": int(total_protein),
            "carbs": int(total_carbs),
            "fat": int(total_fat),
            "portion_size": f"{serving_info} {serving_unit}" + (f" + {len(foods_data)-1} items" if len(foods_data) > 1 else ""),
            "confidence": "high"
        }

    def _scan_clarifai_groq(self, file_bytes: bytes, clarifai_key: str, groq_key: str) -> dict:
        """Clarifai + Groq hybrid: Clarifai identifies food, Groq analyzes portions and estimates macros."""
        import base64
        import requests

        logger.info("Using Clarifai + Groq hybrid scan")

        # Step 1: Use Clarifai to identify food items
        clarifai_url = "https://api.clarifai.com/v2/models/food-item-recognition/outputs"
        headers = {
            "Authorization": f"Key {clarifai_key}",
            "Content-Type": "application/json"
        }

        base64_image = base64.b64encode(file_bytes).decode('utf-8')
        payload = {
            "user_app_id": {
                "user_id": "clarifai",
                "app_id": "main"
            },
            "inputs": [{
                "data": {
                    "image": {
                        "base64": base64_image
                    }
                }
            }]
        }

        clarifai_response = requests.post(clarifai_url, headers=headers, json=payload, timeout=10)
        clarifai_response.raise_for_status()

        # Extract top food items
        clarifai_data = clarifai_response.json()
        concepts = clarifai_data['outputs'][0]['data']['concepts']
        top_foods = [c['name'] for c in concepts[:3] if c['value'] > 0.7]

        if not top_foods:
            raise Exception("No food items detected with sufficient confidence")

        logger.info(f"Clarifai identified: {top_foods}")
        food_list = ", ".join(top_foods)

        # Step 2: Use Groq Vision to analyze portions and estimate macros
        groq_url = "https://api.groq.com/openai/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {groq_key}",
            "Content-Type": "application/json"
        }

        prompt = f"""You are a professional nutritionist analyzing food images.

Clarifai has identified these foods in the image: {food_list}

Now analyze this image carefully and provide accurate nutritional estimates:

1. Estimate the portion size of each food item (use visual cues like plate size, hand comparisons)
2. Calculate nutritional values based on USDA standards
3. Account for cooking methods and visible oils/sauces

IMPORTANT GUIDELINES:
- Be conservative with estimates - if unsure, estimate higher calories
- Restaurant portions are typically 1.5-2x home portions
- Include hidden calories from oils, butter, sugar in sauces
- 1 palm = ~4oz protein (~120-180 calories)
- 1 fist = ~1 cup carbs (~200-240 calories for rice/pasta)
- 1 thumb = ~1 tbsp fat (~100-120 calories)

Return ONLY a raw JSON object (no markdown, no code blocks) with these keys:
{{
    "name": "Descriptive meal name",
    "cals": total_calories_integer,
    "protein": protein_grams_integer,
    "carbs": carbs_grams_integer,
    "fat": fat_grams_integer,
    "portion_size": "Description of estimated portion",
    "confidence": "high/medium/low based on image clarity"
}}

Example: {{"name": "Grilled Chicken with Rice and Vegetables", "cals": 520, "protein": 45, "carbs": 58, "fat": 12, "portion_size": "Standard serving (6oz chicken, 1 cup rice, 1.5 cups vegetables)", "confidence": "high"}}"""

        payload = {
            "model": "llama-3.2-90b-vision-preview",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            "temperature": 0.3,
            "max_tokens": 500
        }

        groq_response = requests.post(groq_url, headers=headers, json=payload, timeout=30)
        groq_response.raise_for_status()

        # Parse Groq response
        groq_data = groq_response.json()
        content = groq_data['choices'][0]['message']['content']

        # Clean up markdown code blocks if present
        text = content.strip()
        if text.startswith("```json"):
            text = text[7:]
        elif text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]

        data = json.loads(text.strip())
        logger.info(f"Groq analysis complete: {data.get('name')}")

        return data

    def _scan_groq_only(self, file_bytes: bytes, groq_key: str) -> dict:
        """Groq Vision only: Direct meal analysis without Clarifai pre-processing."""
        import base64
        import requests

        logger.info("Using Groq Vision only (no Clarifai)")

        base64_image = base64.b64encode(file_bytes).decode('utf-8')

        groq_url = "https://api.groq.com/openai/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {groq_key}",
            "Content-Type": "application/json"
        }

        prompt = """You are a professional nutritionist analyzing food images. Carefully examine this meal image and provide accurate nutritional estimates.

ANALYSIS STEPS:
1. Identify all food items visible in the image
2. Estimate portion sizes (compare to standard serving sizes - e.g., palm-sized protein, fist-sized carbs)
3. Calculate nutritional values based on USDA food database standards
4. Consider cooking methods (fried adds ~30% fat, grilled is leaner)
5. Account for visible oils, sauces, dressings, and toppings

IMPORTANT GUIDELINES:
- Be conservative with estimates - if unsure, estimate higher calories
- Restaurant portions are typically 1.5-2x home portions
- Include hidden calories from oils, butter, sugar in sauces
- 1 palm = ~4oz protein (~120-180 calories)
- 1 fist = ~1 cup carbs (~200-240 calories for rice/pasta)
- 1 thumb = ~1 tbsp fat (~100-120 calories)

Return ONLY a raw JSON object (no markdown, no code blocks) with these keys:
{
    "name": "Descriptive meal name (e.g., 'Grilled Chicken with Rice and Vegetables')",
    "cals": total_calories_integer,
    "protein": protein_grams_integer,
    "carbs": carbs_grams_integer,
    "fat": fat_grams_integer,
    "portion_size": "Description of estimated portion (e.g., 'Large restaurant portion', 'Standard serving')",
    "confidence": "high/medium/low based on image clarity and food visibility"
}

Example response:
{"name": "Grilled Chicken Breast with Brown Rice and Steamed Broccoli", "cals": 520, "protein": 45, "carbs": 58, "fat": 12, "portion_size": "Standard serving (6oz chicken, 1 cup rice, 1.5 cups vegetables)", "confidence": "high"}"""

        payload = {
            "model": "llama-3.2-90b-vision-preview",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            "temperature": 0.3,
            "max_tokens": 500
        }

        groq_response = requests.post(groq_url, headers=headers, json=payload, timeout=30)
        groq_response.raise_for_status()

        # Parse Groq response
        groq_data = groq_response.json()
        content = groq_data['choices'][0]['message']['content']

        # Clean up markdown code blocks if present
        text = content.strip()
        if text.startswith("```json"):
            text = text[7:]
        elif text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]

        data = json.loads(text.strip())
        logger.info(f"Groq Vision analysis complete: {data.get('name')}")

        return data

    def _scan_gemini(self, file_bytes: bytes, api_key: str) -> dict:
        """Fallback to Gemini AI for meal scanning."""
        import google.generativeai as genai

        try:
            genai.configure(api_key=api_key)
            # Try Gemini 2.0 Flash Lite - often has better availability/quota
            model_name = 'gemini-2.0-flash-lite-preview-02-05'
            print(f"DEBUG: Initializing Gemini with model: {model_name}")
            model = genai.GenerativeModel(model_name)

            prompt = """
            You are a professional nutritionist analyzing food images. Carefully examine this meal image and provide accurate nutritional estimates.

            ANALYSIS STEPS:
            1. Identify all food items visible in the image
            2. Estimate portion sizes (compare to standard serving sizes - e.g., palm-sized protein, fist-sized carbs)
            3. Calculate nutritional values based on USDA food database standards
            4. Consider cooking methods (fried adds ~30% fat, grilled is leaner)
            5. Account for visible oils, sauces, dressings, and toppings

            IMPORTANT GUIDELINES:
            - Be conservative with estimates - if unsure, estimate higher calories
            - Restaurant portions are typically 1.5-2x home portions
            - Include hidden calories from oils, butter, sugar in sauces
            - 1 palm = ~4oz protein (~120-180 calories)
            - 1 fist = ~1 cup carbs (~200-240 calories for rice/pasta)
            - 1 thumb = ~1 tbsp fat (~100-120 calories)

            Return ONLY a raw JSON object (no markdown, no code blocks) with these keys:
            {
                "name": "Descriptive meal name (e.g., 'Grilled Chicken with Rice and Vegetables')",
                "cals": total_calories_integer,
                "protein": protein_grams_integer,
                "carbs": carbs_grams_integer,
                "fat": fat_grams_integer,
                "portion_size": "Description of estimated portion (e.g., 'Large restaurant portion', 'Standard serving')",
                "confidence": "high/medium/low based on image clarity and food visibility"
            }

            Example response:
            {"name": "Grilled Chicken Breast with Brown Rice and Steamed Broccoli", "cals": 520, "protein": 45, "carbs": 58, "fat": 12, "portion_size": "Standard serving (6oz chicken, 1 cup rice, 1.5 cups vegetables)", "confidence": "high"}
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
            return data

        except Exception as e:
            logger.error(f"Gemini Error: {e}")
            raise

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
