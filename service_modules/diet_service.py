"""
Diet Service - handles meal scanning, logging, and diet assignment.
"""
from .base import (
    HTTPException, json, logging, date, datetime,
    get_db_session, ClientDietSettingsORM, ClientDietLogORM,
    ClientDailyDietSummaryORM
)
from models import AssignDietRequest

logger = logging.getLogger("gym_app")


class DietService:
    """Service for managing client diet, meal scanning, and logging."""

    def scan_meal(self, file_bytes: bytes) -> dict:
        """Scan a meal image using MacroFactor-style approach: AI identifies foods, database provides accurate macros."""
        import os
        import random
        import sys
        # Add parent directory to path for mock_meals import
        parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if parent_dir not in sys.path:
            sys.path.insert(0, parent_dir)
        from mock_meals import MOCK_MEALS

        gemini_key = os.environ.get("GEMINI_API_KEY")
        usda_key = os.environ.get("USDA_API_KEY")
        nutritionix_app_id = os.environ.get("NUTRITIONIX_APP_ID")
        nutritionix_api_key = os.environ.get("NUTRITIONIX_API_KEY")

        # BEST FREE: Open Food Facts (no API key, excellent for Italian/European foods)
        if gemini_key:
            try:
                result = self._scan_gemini_openfoodfacts(file_bytes, gemini_key)
                return {"status": "success", "data": result, "method": "gemini_openfoodfacts"}
            except Exception as e:
                logger.error(f"Gemini+OpenFoodFacts scan failed: {e}")

        # BACKUP FREE: MacroFactor-style with USDA (Gemini identifies foods → USDA for accurate macros)
        if gemini_key and usda_key:
            try:
                result = self._scan_gemini_usda(file_bytes, gemini_key, usda_key)
                return {"status": "success", "data": result, "method": "gemini_usda"}
            except Exception as e:
                logger.error(f"Gemini+USDA scan failed: {e}")

        # PREMIUM: MacroFactor-style with Nutritionix (if keys available)
        if gemini_key and nutritionix_app_id and nutritionix_api_key:
            try:
                result = self._scan_macrofactor_style(file_bytes, gemini_key, nutritionix_app_id, nutritionix_api_key)
                return {"status": "success", "data": result, "method": "macrofactor"}
            except Exception as e:
                logger.error(f"MacroFactor-style scan failed: {e}")

        # FALLBACK: Gemini direct estimation (works without database)
        if gemini_key:
            try:
                result = self._scan_gemini(file_bytes, gemini_key)
                return {"status": "success", "data": result, "method": "gemini"}
            except Exception as e:
                logger.error(f"Gemini scan failed: {e}")

        # Legacy fallbacks
        clarifai_key = os.environ.get("CLARIFAI_API_KEY")
        groq_key = os.environ.get("GROQ_API_KEY")

        if clarifai_key and nutritionix_app_id and nutritionix_api_key:
            try:
                result = self._scan_hybrid(file_bytes, clarifai_key, nutritionix_app_id, nutritionix_api_key)
                return {"status": "success", "data": result, "method": "clarifai_nutritionix"}
            except Exception as e:
                logger.error(f"Hybrid scan failed: {e}")

        if clarifai_key and groq_key:
            try:
                result = self._scan_clarifai_groq(file_bytes, clarifai_key, groq_key)
                return {"status": "success", "data": result, "method": "clarifai_groq"}
            except Exception as e:
                logger.error(f"Clarifai+Groq scan failed: {e}")

        if groq_key:
            try:
                result = self._scan_groq_only(file_bytes, groq_key)
                return {"status": "success", "data": result, "method": "groq"}
            except Exception as e:
                logger.error(f"Groq Vision scan failed: {e}")

        # Final fallback: Mock data
        logger.warning("No API keys found, using mock meal database.")
        result = random.choice(MOCK_MEALS)
        return {"status": "success", "data": result, "method": "mock"}

    def lookup_barcode(self, barcode: str) -> dict:
        """Look up a product by barcode using Open Food Facts API.

        This provides accurate nutritional data for packaged foods.
        Open Food Facts has excellent coverage for EU/Italian products.
        """
        import requests

        logger.info(f"Looking up barcode: {barcode}")

        # Try Italian Open Food Facts first, then world database
        api_urls = [
            f"https://it.openfoodfacts.org/api/v0/product/{barcode}.json",
            f"https://world.openfoodfacts.org/api/v0/product/{barcode}.json"
        ]

        for api_url in api_urls:
            try:
                response = requests.get(api_url, timeout=10)

                if not response.ok:
                    continue

                data = response.json()

                if data.get("status") != 1:
                    continue

                product = data.get("product", {})
                nutriments = product.get("nutriments", {})

                # Get product info
                product_name = product.get("product_name") or product.get("product_name_it") or product.get("product_name_en") or "Unknown Product"
                brands = product.get("brands", "")
                quantity = product.get("quantity", "")

                # Parse quantity to get package weight
                package_weight = 100  # default to 100g
                if quantity:
                    import re
                    match = re.search(r'(\d+)\s*g', quantity.lower())
                    if match:
                        package_weight = int(match.group(1))

                # Get nutritional values per 100g
                energy_100g = nutriments.get("energy-kcal_100g") or 0
                if not energy_100g:
                    # Try energy in kJ and convert
                    energy_kj = nutriments.get("energy_100g", 0)
                    if energy_kj:
                        energy_100g = energy_kj / 4.184

                protein_100g = nutriments.get("proteins_100g", 0) or 0
                carbs_100g = nutriments.get("carbohydrates_100g", 0) or 0
                fat_100g = nutriments.get("fat_100g", 0) or 0

                # Calculate per package (full product)
                scale = package_weight / 100.0
                total_calories = round(energy_100g * scale)
                total_protein = round(protein_100g * scale, 1)
                total_carbs = round(carbs_100g * scale, 1)
                total_fat = round(fat_100g * scale, 1)

                full_name = f"{brands} {product_name}".strip() if brands else product_name

                logger.info(f"Found product: {full_name}, {package_weight}g, {total_calories} kcal")

                return {
                    "status": "success",
                    "data": {
                        "name": full_name,
                        "cals": total_calories,
                        "protein": total_protein,
                        "carbs": total_carbs,
                        "fat": total_fat,
                        "portion_size": f"{package_weight}g",
                        "package_weight": package_weight,
                        "per_100g": {
                            "cals": round(energy_100g),
                            "protein": round(protein_100g, 1),
                            "carbs": round(carbs_100g, 1),
                            "fat": round(fat_100g, 1)
                        },
                        "confidence": "high",
                        "source": "openfoodfacts_barcode"
                    },
                    "method": "barcode"
                }

            except Exception as e:
                logger.warning(f"Open Food Facts barcode lookup error: {e}")
                continue

        # Product not found
        logger.warning(f"Barcode {barcode} not found in Open Food Facts")
        return {
            "status": "not_found",
            "message": f"Product with barcode {barcode} not found. Try taking a photo instead.",
            "barcode": barcode
        }

    def _scan_macrofactor_style(self, file_bytes: bytes, gemini_key: str, nutritionix_app_id: str, nutritionix_api_key: str) -> dict:
        """MacroFactor-style: Gemini identifies individual foods, Nutritionix provides accurate macros."""
        import base64
        import requests
        import google.generativeai as genai
        from PIL import Image
        import io

        logger.info("Using MacroFactor-style scan (Gemini + Nutritionix)")

        # Step 1: Use Gemini to identify individual food items
        genai.configure(api_key=gemini_key)
        model = genai.GenerativeModel('models/gemini-2.0-flash')

        # Load image
        image = Image.open(io.BytesIO(file_bytes))

        prompt = """Analyze this food image and identify each individual food item visible.

For EACH food item, provide:
1. The food name (be specific - e.g., "grilled chicken breast" not just "chicken")
2. Estimated portion size (e.g., "6 oz", "1 cup", "2 slices")

Return ONLY a JSON array of objects, no markdown, no explanation:
[
    {"food": "grilled chicken breast", "portion": "6 oz"},
    {"food": "white rice", "portion": "1 cup"},
    {"food": "steamed broccoli", "portion": "1 cup"}
]

Be specific about:
- Cooking method (grilled, fried, baked, steamed)
- Type (white rice vs brown rice, chicken breast vs thigh)
- Portion sizes in standard units (oz, cups, pieces, slices)"""

        response = model.generate_content([prompt, image])
        text = response.text.strip()

        # Clean up markdown if present
        if text.startswith("```json"):
            text = text[7:]
        elif text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]

        food_items = json.loads(text.strip())
        logger.info(f"Gemini identified {len(food_items)} food items: {food_items}")

        # Step 2: Look up each food in Nutritionix
        items_with_macros = []
        total_cals = 0
        total_protein = 0
        total_carbs = 0
        total_fat = 0

        for item in food_items:
            query = f"{item['portion']} {item['food']}"
            macros = self._nutritionix_lookup(query, nutritionix_app_id, nutritionix_api_key)

            items_with_macros.append({
                "food": item['food'],
                "portion": item['portion'],
                "cals": macros['cals'],
                "protein": macros['protein'],
                "carbs": macros['carbs'],
                "fat": macros['fat']
            })

            total_cals += macros['cals']
            total_protein += macros['protein']
            total_carbs += macros['carbs']
            total_fat += macros['fat']

        # Build meal name from items
        meal_name = " + ".join([item['food'].title() for item in food_items[:3]])
        if len(food_items) > 3:
            meal_name += f" + {len(food_items) - 3} more"

        return {
            "name": meal_name,
            "cals": round(total_cals),
            "protein": round(total_protein),
            "carbs": round(total_carbs),
            "fat": round(total_fat),
            "items": items_with_macros,  # Itemized breakdown like MacroFactor
            "portion_size": f"{len(food_items)} items identified",
            "confidence": "high"
        }

    def _nutritionix_lookup(self, query: str, app_id: str, api_key: str) -> dict:
        """Look up food in Nutritionix database for accurate macros."""
        import requests

        url = "https://trackapi.nutritionix.com/v2/natural/nutrients"
        headers = {
            "x-app-id": app_id,
            "x-app-key": api_key,
            "Content-Type": "application/json"
        }
        payload = {"query": query}

        response = requests.post(url, headers=headers, json=payload, timeout=10)

        if not response.ok:
            logger.warning(f"Nutritionix lookup failed for '{query}': {response.text}")
            # Return zeros if lookup fails
            return {"cals": 0, "protein": 0, "carbs": 0, "fat": 0}

        data = response.json()
        foods = data.get("foods", [])

        if not foods:
            return {"cals": 0, "protein": 0, "carbs": 0, "fat": 0}

        # Sum up all foods returned (Nutritionix may split into multiple items)
        total = {"cals": 0, "protein": 0, "carbs": 0, "fat": 0}
        for food in foods:
            total["cals"] += food.get("nf_calories", 0) or 0
            total["protein"] += food.get("nf_protein", 0) or 0
            total["carbs"] += food.get("nf_total_carbohydrate", 0) or 0
            total["fat"] += food.get("nf_total_fat", 0) or 0

        return total

    def _scan_gemini_nutritionix(self, file_bytes: bytes, gemini_key: str, nutritionix_app_id: str, nutritionix_api_key: str) -> dict:
        """Alias for MacroFactor-style scan."""
        return self._scan_macrofactor_style(file_bytes, gemini_key, nutritionix_app_id, nutritionix_api_key)

    def _scan_gemini_openfoodfacts(self, file_bytes: bytes, gemini_key: str) -> dict:
        """Direct Gemini vision analysis with comprehensive food knowledge.

        Uses Gemini's visual analysis with detailed nutritional reference tables
        for maximum accuracy. No database blending - pure AI vision.
        """
        import google.generativeai as genai
        from PIL import Image
        import io

        logger.info("Using Gemini Vision direct analysis (high accuracy mode)")

        genai.configure(api_key=gemini_key)

        # Try multiple models for quota availability
        models_to_try = [
            'gemini-2.5-flash',
            'gemini-2.5-flash-lite',
            'gemini-2.0-flash-lite',
            'gemini-2.0-flash',
        ]

        # Load image
        image = Image.open(io.BytesIO(file_bytes))

        prompt = """You are analyzing a food image for a user in ITALY/EUROPE. Your #1 priority is ACCURACY.

=== CRITICAL: USE ONLY EU/ITALIAN DATA ===
- This user is in ITALY. Use ONLY European/Italian nutritional data.
- DO NOT use US nutritional data - US package sizes and formulations are different!
- EU Pringles: 165g can = ~528 kcal (NOT 900 kcal like US)
- EU packages show "per 100g" values - use these for calculations

=== RULE #1: ALWAYS READ THE LABEL ===
If this is PACKAGED FOOD with a visible nutrition label:
- LOOK for the nutrition facts table on the package
- READ the exact values: kcal, protein, carbs, fat per 100g
- READ the total package weight (usually on front or back)
- CALCULATE: (per 100g value) × (package weight / 100) = total
- USE EXACTLY what the label says - do NOT use memorized US data

=== RULE #2: NO LABEL VISIBLE ===
Only if you CANNOT see a nutrition label, use EU reference data:

EU Packaged snacks (per 100g):
- Pringles/chips: ~520 kcal, 5g protein, 50g carbs, 32g fat
- Chocolate bars: ~530 kcal
- Cookies/biscuits: ~480 kcal

Common EU package sizes:
- Pringles tube: 165g (Italy) = ~528 kcal total
- Chocolate bar: 100g standard
- Crisps bag: 150g

Italian prepared foods (per 100g):
- Pasta with tomato sauce: 140 kcal
- Pasta carbonara: 190 kcal
- Pizza margherita: 240 kcal
- Risotto: 160 kcal
- Grilled chicken: 165 kcal

=== OUTPUT FORMAT ===
Return ONLY this JSON (no markdown, no extra text):
{
    "items": [
        {
            "food": "exact product name",
            "portion_grams": weight,
            "kcal": calories_EU_data_only,
            "protein": protein_grams,
            "carbs": carb_grams,
            "fat": fat_grams
        }
    ],
    "total_kcal": sum,
    "total_protein": sum,
    "total_carbs": sum,
    "total_fat": sum,
    "meal_name": "product name with brand",
    "confidence": "high if read from label, medium if estimated",
    "notes": "EU-data or label-read"
}

CRITICAL: Use ONLY European/Italian nutritional data. NEVER use US data."""

        # Try generation with fallback to other models if quota exceeded
        response = None
        for model_name in models_to_try:
            try:
                model = genai.GenerativeModel(model_name)
                logger.info(f"Attempting generation with: {model_name}")
                response = model.generate_content([prompt, image])
                logger.info(f"Success with model: {model_name}")
                break
            except Exception as e:
                error_str = str(e)
                if "429" in error_str or "quota" in error_str.lower():
                    logger.warning(f"Quota exceeded for {model_name}, trying next model...")
                    continue
                else:
                    raise

        if not response:
            raise Exception("All Gemini models quota exceeded")

        text = response.text.strip()
        logger.info(f"Raw Gemini response: {text[:500]}...")

        # Clean up markdown if present
        if text.startswith("```json"):
            text = text[7:]
        elif text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]

        result = json.loads(text.strip())
        logger.info(f"Parsed result: {result}")

        # Format response for the app
        items_with_macros = []
        for item in result.get('items', []):
            items_with_macros.append({
                "food": item.get('food', 'Unknown'),
                "portion": f"{item.get('portion_grams', 100)}g",
                "cals": item.get('kcal', 0),
                "protein": item.get('protein', 0),
                "carbs": item.get('carbs', 0),
                "fat": item.get('fat', 0),
                "source": "gemini_vision"
            })

        return {
            "name": result.get('meal_name', 'Scanned Meal'),
            "cals": result.get('total_kcal', 0),
            "protein": result.get('total_protein', 0),
            "carbs": result.get('total_carbs', 0),
            "fat": result.get('total_fat', 0),
            "items": items_with_macros,
            "portion_size": f"{len(items_with_macros)} items identified",
            "confidence": result.get('confidence', 'medium'),
            "accuracy_note": result.get('notes', 'AI vision analysis')
        }

    def _openfoodfacts_lookup(self, food_name: str, portion_grams: int = 100) -> dict:
        """Look up food in FREE Open Food Facts database - great for Italian/European foods.

        No API key required! Community-driven database with excellent international coverage.
        """
        import requests

        # Try Italian Open Food Facts first, then world database
        search_urls = [
            "https://it.openfoodfacts.org/cgi/search.pl",  # Italian database first
            "https://world.openfoodfacts.org/cgi/search.pl"  # Fallback to world
        ]

        for search_url in search_urls:
            try:
                params = {
                    "search_terms": food_name,
                    "search_simple": 1,
                    "action": "process",
                    "json": 1,
                    "page_size": 5,
                    "fields": "product_name,nutriments"
                }

                response = requests.get(search_url, params=params, timeout=10)

                if not response.ok:
                    continue

                data = response.json()
                products = data.get("products", [])

                if not products:
                    continue

                # Find best match (first product with nutrient data)
                for product in products:
                    nutriments = product.get("nutriments", {})

                    # Get values per 100g
                    energy = nutriments.get("energy-kcal_100g") or nutriments.get("energy_100g", 0)
                    # If energy is in kJ, convert to kcal
                    if energy and energy > 1000:  # Likely kJ
                        energy = energy / 4.184

                    protein = nutriments.get("proteins_100g", 0)
                    carbs = nutriments.get("carbohydrates_100g", 0)
                    fat = nutriments.get("fat_100g", 0)

                    # Only use if we have meaningful data
                    if energy or protein or carbs or fat:
                        scale = portion_grams / 100.0
                        logger.info(f"Open Food Facts found: {product.get('product_name', food_name)}")
                        return {
                            "cals": round((energy or 0) * scale),
                            "protein": round((protein or 0) * scale),
                            "carbs": round((carbs or 0) * scale),
                            "fat": round((fat or 0) * scale),
                            "source": "openfoodfacts"
                        }

            except Exception as e:
                logger.warning(f"Open Food Facts search error: {e}")
                continue

        # Fallback to estimation
        logger.warning(f"No Open Food Facts results for '{food_name}', using estimation")
        macros = self._estimate_macros(food_name, portion_grams)
        macros["source"] = "estimated"
        return macros

    def _scan_gemini_usda(self, file_bytes: bytes, gemini_key: str, usda_key: str) -> dict:
        """MacroFactor-style with FREE USDA database: Gemini identifies foods, USDA provides accurate macros."""
        import base64
        import requests
        import google.generativeai as genai
        from PIL import Image
        import io

        logger.info("Using Gemini + USDA (FREE) scan")

        # Step 1: Use Gemini to identify individual food items
        genai.configure(api_key=gemini_key)
        model = genai.GenerativeModel('models/gemini-2.0-flash')

        # Load image
        image = Image.open(io.BytesIO(file_bytes))

        prompt = """Analyze this food image and identify each individual food item visible.

For EACH food item, provide:
1. The food name (be specific - e.g., "grilled chicken breast" not just "chicken")
2. Estimated portion size in grams or standard units

Return ONLY a JSON array of objects, no markdown, no explanation:
[
    {"food": "grilled chicken breast", "portion": "170g", "portion_grams": 170},
    {"food": "white rice cooked", "portion": "1 cup", "portion_grams": 200},
    {"food": "steamed broccoli", "portion": "1 cup", "portion_grams": 90}
]

Be specific about:
- Cooking method (grilled, fried, baked, steamed, raw)
- Type (white rice vs brown rice, chicken breast vs thigh)
- Include portion_grams as estimated weight in grams"""

        response = model.generate_content([prompt, image])
        text = response.text.strip()

        # Clean up markdown if present
        if text.startswith("```json"):
            text = text[7:]
        elif text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]

        food_items = json.loads(text.strip())
        logger.info(f"Gemini identified {len(food_items)} food items: {food_items}")

        # Step 2: Look up each food in USDA database
        items_with_macros = []
        total_cals = 0
        total_protein = 0
        total_carbs = 0
        total_fat = 0

        for item in food_items:
            portion_grams = item.get('portion_grams', 100)
            macros = self._usda_lookup(item['food'], usda_key, portion_grams)

            items_with_macros.append({
                "food": item['food'],
                "portion": item['portion'],
                "cals": macros['cals'],
                "protein": macros['protein'],
                "carbs": macros['carbs'],
                "fat": macros['fat']
            })

            total_cals += macros['cals']
            total_protein += macros['protein']
            total_carbs += macros['carbs']
            total_fat += macros['fat']

        # Build meal name from items
        meal_name = " + ".join([item['food'].title() for item in food_items[:3]])
        if len(food_items) > 3:
            meal_name += f" + {len(food_items) - 3} more"

        return {
            "name": meal_name,
            "cals": round(total_cals),
            "protein": round(total_protein),
            "carbs": round(total_carbs),
            "fat": round(total_fat),
            "items": items_with_macros,
            "portion_size": f"{len(food_items)} items identified",
            "confidence": "high"
        }

    def _usda_lookup(self, food_name: str, api_key: str, portion_grams: int = 100) -> dict:
        """Look up food in FREE USDA FoodData Central database."""
        import requests

        # Search for the food
        search_url = "https://api.nal.usda.gov/fdc/v1/foods/search"
        params = {
            "api_key": api_key,
            "query": food_name,
            "pageSize": 1,
            "dataType": ["Survey (FNDDS)", "Foundation", "SR Legacy"]  # Prefer whole foods data
        }

        try:
            response = requests.get(search_url, params=params, timeout=10)

            if not response.ok:
                logger.warning(f"USDA search failed for '{food_name}': {response.status_code}")
                return self._estimate_macros(food_name, portion_grams)

            data = response.json()
            foods = data.get("foods", [])

            if not foods:
                logger.warning(f"No USDA results for '{food_name}'")
                return self._estimate_macros(food_name, portion_grams)

            # Get first result
            food = foods[0]
            nutrients = {n['nutrientName']: n.get('value', 0) for n in food.get('foodNutrients', [])}

            # USDA values are per 100g, scale to portion size
            scale = portion_grams / 100.0

            return {
                "cals": round((nutrients.get('Energy', 0) or 0) * scale),
                "protein": round((nutrients.get('Protein', 0) or 0) * scale),
                "carbs": round((nutrients.get('Carbohydrate, by difference', 0) or 0) * scale),
                "fat": round((nutrients.get('Total lipid (fat)', 0) or 0) * scale)
            }

        except Exception as e:
            logger.error(f"USDA lookup error for '{food_name}': {e}")
            return self._estimate_macros(food_name, portion_grams)

    def _estimate_macros(self, food_name: str, portion_grams: int) -> dict:
        """Fallback estimation when database lookup fails. Includes Italian/Mediterranean foods."""
        # Basic estimates per 100g for common food categories
        food_lower = food_name.lower()

        # Proteins
        if any(x in food_lower for x in ['chicken', 'turkey', 'pollo']):
            per_100g = {"cals": 165, "protein": 31, "carbs": 0, "fat": 4}
        elif any(x in food_lower for x in ['fish', 'salmon', 'tuna', 'shrimp', 'branzino', 'orata', 'pesce', 'gamberi']):
            per_100g = {"cals": 120, "protein": 22, "carbs": 0, "fat": 3}
        elif any(x in food_lower for x in ['beef', 'steak', 'pork', 'lamb', 'manzo', 'maiale', 'agnello']):
            per_100g = {"cals": 250, "protein": 26, "carbs": 0, "fat": 15}
        elif any(x in food_lower for x in ['prosciutto', 'pancetta', 'salumi', 'speck']):
            per_100g = {"cals": 270, "protein": 24, "carbs": 0, "fat": 19}

        # Italian Pasta dishes (cooked with sauce)
        elif any(x in food_lower for x in ['carbonara']):
            per_100g = {"cals": 180, "protein": 9, "carbs": 20, "fat": 8}
        elif any(x in food_lower for x in ['bolognese', 'ragu']):
            per_100g = {"cals": 160, "protein": 8, "carbs": 18, "fat": 6}
        elif any(x in food_lower for x in ['amatriciana', 'arrabbiata']):
            per_100g = {"cals": 150, "protein": 6, "carbs": 22, "fat": 4}
        elif any(x in food_lower for x in ['cacio e pepe']):
            per_100g = {"cals": 200, "protein": 10, "carbs": 20, "fat": 10}
        elif any(x in food_lower for x in ['lasagna', 'lasagne']):
            per_100g = {"cals": 175, "protein": 10, "carbs": 18, "fat": 8}
        elif any(x in food_lower for x in ['gnocchi']):
            per_100g = {"cals": 130, "protein": 3, "carbs": 28, "fat": 1}

        # Plain carbs
        elif any(x in food_lower for x in ['pasta', 'spaghetti', 'penne', 'rigatoni', 'fettuccine']):
            per_100g = {"cals": 130, "protein": 5, "carbs": 25, "fat": 1}
        elif any(x in food_lower for x in ['rice', 'risotto', 'riso']):
            per_100g = {"cals": 130, "protein": 3, "carbs": 28, "fat": 1}
        elif any(x in food_lower for x in ['bread', 'pane', 'focaccia', 'ciabatta']):
            per_100g = {"cals": 265, "protein": 9, "carbs": 49, "fat": 3}

        # Pizza
        elif any(x in food_lower for x in ['pizza', 'margherita']):
            per_100g = {"cals": 250, "protein": 11, "carbs": 30, "fat": 10}

        # Cheese
        elif any(x in food_lower for x in ['mozzarella']):
            per_100g = {"cals": 280, "protein": 22, "carbs": 2, "fat": 21}
        elif any(x in food_lower for x in ['parmigiano', 'parmesan', 'grana']):
            per_100g = {"cals": 430, "protein": 38, "carbs": 4, "fat": 29}
        elif any(x in food_lower for x in ['ricotta']):
            per_100g = {"cals": 150, "protein": 11, "carbs": 3, "fat": 11}
        elif any(x in food_lower for x in ['cheese', 'formaggio']):
            per_100g = {"cals": 400, "protein": 25, "carbs": 1, "fat": 33}

        # Eggs
        elif any(x in food_lower for x in ['egg', 'uovo', 'uova']):
            per_100g = {"cals": 155, "protein": 13, "carbs": 1, "fat": 11}

        # Vegetables
        elif any(x in food_lower for x in ['broccoli', 'spinach', 'vegetable', 'salad', 'lettuce', 'verdura', 'insalata']):
            per_100g = {"cals": 35, "protein": 3, "carbs": 7, "fat": 0}
        elif any(x in food_lower for x in ['tomato', 'pomodoro']):
            per_100g = {"cals": 20, "protein": 1, "carbs": 4, "fat": 0}
        elif any(x in food_lower for x in ['zucchini', 'zucchine', 'eggplant', 'melanzane']):
            per_100g = {"cals": 25, "protein": 1, "carbs": 5, "fat": 0}
        elif any(x in food_lower for x in ['potato', 'patate', 'fries']):
            per_100g = {"cals": 150, "protein": 2, "carbs": 33, "fat": 0}

        # Fats
        elif any(x in food_lower for x in ['olive oil', 'olio']):
            per_100g = {"cals": 880, "protein": 0, "carbs": 0, "fat": 100}
        elif any(x in food_lower for x in ['butter', 'burro']):
            per_100g = {"cals": 720, "protein": 1, "carbs": 0, "fat": 81}

        # Desserts
        elif any(x in food_lower for x in ['tiramisu']):
            per_100g = {"cals": 290, "protein": 5, "carbs": 30, "fat": 17}
        elif any(x in food_lower for x in ['gelato', 'ice cream']):
            per_100g = {"cals": 200, "protein": 4, "carbs": 24, "fat": 10}
        elif any(x in food_lower for x in ['cannoli']):
            per_100g = {"cals": 320, "protein": 6, "carbs": 35, "fat": 18}
        elif any(x in food_lower for x in ['panna cotta']):
            per_100g = {"cals": 240, "protein": 3, "carbs": 20, "fat": 17}

        else:
            per_100g = {"cals": 150, "protein": 8, "carbs": 15, "fat": 7}

        scale = portion_grams / 100.0
        return {
            "cals": round(per_100g["cals"] * scale),
            "protein": round(per_100g["protein"] * scale),
            "carbs": round(per_100g["carbs"] * scale),
            "fat": round(per_100g["fat"] * scale)
        }

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

        # Extract top food items with adaptive threshold
        clarifai_data = clarifai_response.json()
        concepts = clarifai_data['outputs'][0]['data']['concepts']

        # Adaptive threshold: try 0.7, then 0.5, then 0.3
        thresholds = [0.7, 0.5, 0.3]
        top_foods = []
        used_threshold = None

        for threshold in thresholds:
            top_foods = [c['name'] for c in concepts[:3] if c['value'] > threshold]
            if top_foods:
                used_threshold = threshold
                break

        if not top_foods:
            raise Exception("No food items detected with sufficient confidence")

        logger.info(f"Clarifai used threshold: {used_threshold} (detected: {top_foods})")

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

        # Extract top food items with adaptive threshold
        clarifai_data = clarifai_response.json()
        concepts = clarifai_data['outputs'][0]['data']['concepts']

        # Adaptive threshold: try 0.7, then 0.5, then 0.3
        thresholds = [0.7, 0.5, 0.3]
        top_foods = []
        used_threshold = None

        for threshold in thresholds:
            top_foods = [c['name'] for c in concepts[:3] if c['value'] > threshold]
            if top_foods:
                used_threshold = threshold
                break

        if not top_foods:
            raise Exception("No food items detected with sufficient confidence")

        logger.info(f"Clarifai identified: {top_foods} (threshold: {used_threshold})")
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

COMMON FOODS TO RECOGNIZE:
- Burgers/Hamburgers: beef patty, bun, cheese, lettuce, tomato, condiments
- Sandwiches: bread, deli meat, cheese, vegetables
- Pizza: dough, cheese, sauce, toppings (pepperoni, vegetables, etc.)
- Pasta dishes: spaghetti, penne, fettuccine with various sauces
- Asian cuisine: rice bowls, noodles, sushi, stir-fry
- Mexican: tacos, burritos, quesadillas, nachos
- Breakfast: eggs, bacon, pancakes, waffles, toast
- Salads: leafy greens with proteins, dressings, toppings
- Fast food: fries, chicken nuggets, burgers, sandwiches

IMPORTANT GUIDELINES:
- Be conservative with estimates - if unsure, estimate higher calories
- Restaurant portions are typically 1.5-2x home portions
- Include hidden calories from oils, butter, sugar in sauces
- Burgers typically: 300-800 calories (depending on size and toppings)
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
            "model": "llama-3.2-11b-vision-preview",
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

COMMON FOODS TO RECOGNIZE:
- Burgers/Hamburgers: beef patty, bun, cheese, lettuce, tomato, condiments (300-800 cals)
- Sandwiches: bread, deli meat, cheese, vegetables (250-600 cals)
- Pizza: dough, cheese, sauce, toppings - 1 slice = 250-350 cals
- Pasta dishes: spaghetti, penne, fettuccine with various sauces (400-800 cals per serving)
- Asian cuisine: rice bowls, noodles, sushi, stir-fry (400-700 cals)
- Mexican: tacos, burritos, quesadillas, nachos (350-900 cals)
- Breakfast: eggs (70-90 each), bacon (40-50 per strip), pancakes (150-200 each)
- Salads: leafy greens with proteins, dressings, toppings (200-600 cals)
- Fast food: fries (300-500 cals), chicken nuggets (40-50 per nugget)

IMPORTANT GUIDELINES:
- Be conservative with estimates - if unsure, estimate higher calories
- Restaurant portions are typically 1.5-2x home portions
- Include hidden calories from oils, butter, sugar in sauces
- Burgers typically: 300-800 calories (depending on size and toppings)
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
            "model": "llama-3.2-11b-vision-preview",
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

    def _test_groq_api(self, groq_key: str) -> str:
        """Test Groq API and return available models."""
        import requests
        url = "https://api.groq.com/openai/v1/models"
        headers = {"Authorization": f"Bearer {groq_key}"}
        response = requests.get(url, headers=headers, timeout=10)
        return response.text

    def _scan_gemini(self, file_bytes: bytes, api_key: str) -> dict:
        """Fallback to Gemini AI for meal scanning."""
        import google.generativeai as genai

        try:
            genai.configure(api_key=api_key)
            # Use Gemini 2.0 Flash - widely available with good quotas
            model_name = 'models/gemini-2.0-flash'
            logger.info(f"Using Gemini model: {model_name}")
            model = genai.GenerativeModel(model_name)

            prompt = """
            You are a professional nutritionist analyzing food images. Carefully examine this meal image and provide accurate nutritional estimates.

            ANALYSIS STEPS:
            1. Identify all food items visible in the image
            2. Estimate portion sizes (compare to standard serving sizes - e.g., palm-sized protein, fist-sized carbs)
            3. Calculate nutritional values based on USDA food database standards
            4. Consider cooking methods (fried adds ~30% fat, grilled is leaner)
            5. Account for visible oils, sauces, dressings, and toppings

            COMMON FOODS TO RECOGNIZE:
            - Burgers/Hamburgers: beef patty, bun, cheese, lettuce, tomato, condiments (300-800 cals)
            - Sandwiches: bread, deli meat, cheese, vegetables (250-600 cals)
            - Pizza: dough, cheese, sauce, toppings - 1 slice = 250-350 cals
            - Pasta dishes: spaghetti, penne, fettuccine with various sauces (400-800 cals per serving)
            - Asian cuisine: rice bowls, noodles, sushi, stir-fry (400-700 cals)
            - Mexican: tacos, burritos, quesadillas, nachos (350-900 cals)
            - Breakfast: eggs (70-90 each), bacon (40-50 per strip), pancakes (150-200 each)
            - Salads: leafy greens with proteins, dressings, toppings (200-600 cals)
            - Fast food: fries (300-500 cals), chicken nuggets (40-50 per nugget)

            IMPORTANT GUIDELINES:
            - Be conservative with estimates - if unsure, estimate higher calories
            - Restaurant portions are typically 1.5-2x home portions
            - Include hidden calories from oils, butter, sugar in sauces
            - Burgers typically: 300-800 calories (depending on size and toppings)
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
            today = date.today().isoformat()

            # Get or create settings
            settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
            if not settings:
                settings = ClientDietSettingsORM(id=client_id, last_reset_date=today)
                db.add(settings)
                db.flush()

            # Check if it's a new day - if so, save yesterday's totals and reset
            if settings.last_reset_date and settings.last_reset_date != today:
                # Save yesterday's totals to daily summary
                yesterday_summary = ClientDailyDietSummaryORM(
                    client_id=client_id,
                    date=settings.last_reset_date,
                    total_calories=settings.calories_current,
                    total_protein=settings.protein_current,
                    total_carbs=settings.carbs_current,
                    total_fat=settings.fat_current,
                    total_hydration=settings.hydration_current,
                    target_calories=settings.calories_target,
                    target_protein=settings.protein_target,
                    target_carbs=settings.carbs_target,
                    target_fat=settings.fat_target,
                    meal_count=db.query(ClientDietLogORM).filter(
                        ClientDietLogORM.client_id == client_id,
                        ClientDietLogORM.date == settings.last_reset_date
                    ).count()
                )
                db.add(yesterday_summary)

                # Reset current values for new day
                settings.calories_current = 0
                settings.protein_current = 0
                settings.carbs_current = 0
                settings.fat_current = 0
                settings.hydration_current = 0
                settings.last_reset_date = today

                logger.info(f"Saved daily summary for {client_id} on {settings.last_reset_date} and reset for {today}")

            # Log the meal
            log = ClientDietLogORM(
                client_id=client_id,
                date=today,
                meal_type=meal_data.get("meal_type", "Snack"),
                meal_name=meal_data.get("name"),
                calories=meal_data.get("cals"),
                time=datetime.now().strftime("%H:%M")
            )
            db.add(log)

            # Update current day's macros
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
