"""
Mock Meals Database - Fallback data for meal scanning when no API keys are configured.
Contains 120+ realistic meal entries with nutritional information.
"""

MOCK_MEALS = [
    # Breakfast items
    {"name": "Scrambled Eggs with Toast", "cals": 350, "protein": 18, "carbs": 28, "fat": 18, "portion_size": "2 eggs + 2 slices", "confidence": "mock"},
    {"name": "Oatmeal with Banana", "cals": 320, "protein": 8, "carbs": 58, "fat": 6, "portion_size": "1 cup oatmeal + 1 banana", "confidence": "mock"},
    {"name": "Greek Yogurt Parfait", "cals": 280, "protein": 15, "carbs": 35, "fat": 8, "portion_size": "1 cup yogurt + granola", "confidence": "mock"},
    {"name": "Avocado Toast", "cals": 290, "protein": 7, "carbs": 24, "fat": 19, "portion_size": "2 slices with half avocado", "confidence": "mock"},
    {"name": "Protein Pancakes", "cals": 420, "protein": 28, "carbs": 45, "fat": 12, "portion_size": "3 medium pancakes", "confidence": "mock"},
    {"name": "Breakfast Burrito", "cals": 480, "protein": 22, "carbs": 42, "fat": 24, "portion_size": "1 large burrito", "confidence": "mock"},
    {"name": "Smoothie Bowl", "cals": 340, "protein": 12, "carbs": 52, "fat": 10, "portion_size": "1 bowl", "confidence": "mock"},
    {"name": "Eggs Benedict", "cals": 520, "protein": 24, "carbs": 32, "fat": 34, "portion_size": "2 eggs on muffin", "confidence": "mock"},
    {"name": "Fruit and Cottage Cheese", "cals": 220, "protein": 18, "carbs": 24, "fat": 5, "portion_size": "1 cup cottage cheese + fruit", "confidence": "mock"},
    {"name": "Bacon and Eggs", "cals": 400, "protein": 25, "carbs": 2, "fat": 32, "portion_size": "3 eggs + 4 strips bacon", "confidence": "mock"},

    # Lunch items
    {"name": "Grilled Chicken Salad", "cals": 380, "protein": 35, "carbs": 18, "fat": 18, "portion_size": "1 large bowl", "confidence": "mock"},
    {"name": "Turkey Sandwich", "cals": 420, "protein": 28, "carbs": 38, "fat": 16, "portion_size": "1 sandwich", "confidence": "mock"},
    {"name": "Caesar Salad with Chicken", "cals": 450, "protein": 32, "carbs": 22, "fat": 26, "portion_size": "1 large plate", "confidence": "mock"},
    {"name": "Tuna Wrap", "cals": 380, "protein": 26, "carbs": 32, "fat": 16, "portion_size": "1 wrap", "confidence": "mock"},
    {"name": "Chicken Quesadilla", "cals": 520, "protein": 30, "carbs": 38, "fat": 28, "portion_size": "1 large quesadilla", "confidence": "mock"},
    {"name": "Veggie Burger", "cals": 380, "protein": 18, "carbs": 42, "fat": 14, "portion_size": "1 burger", "confidence": "mock"},
    {"name": "Soup and Sandwich Combo", "cals": 480, "protein": 22, "carbs": 52, "fat": 18, "portion_size": "1 bowl + half sandwich", "confidence": "mock"},
    {"name": "Poke Bowl", "cals": 520, "protein": 32, "carbs": 58, "fat": 16, "portion_size": "1 regular bowl", "confidence": "mock"},
    {"name": "BLT Sandwich", "cals": 440, "protein": 18, "carbs": 34, "fat": 26, "portion_size": "1 sandwich", "confidence": "mock"},
    {"name": "Greek Salad", "cals": 320, "protein": 12, "carbs": 18, "fat": 24, "portion_size": "1 large bowl", "confidence": "mock"},

    # Dinner items
    {"name": "Grilled Salmon with Vegetables", "cals": 480, "protein": 42, "carbs": 18, "fat": 26, "portion_size": "6oz salmon + veggies", "confidence": "mock"},
    {"name": "Chicken Stir Fry", "cals": 420, "protein": 35, "carbs": 32, "fat": 16, "portion_size": "1.5 cups", "confidence": "mock"},
    {"name": "Beef Steak with Potatoes", "cals": 620, "protein": 48, "carbs": 35, "fat": 32, "portion_size": "8oz steak + medium potato", "confidence": "mock"},
    {"name": "Pasta with Meat Sauce", "cals": 580, "protein": 28, "carbs": 68, "fat": 20, "portion_size": "2 cups pasta", "confidence": "mock"},
    {"name": "Grilled Chicken Breast", "cals": 280, "protein": 42, "carbs": 0, "fat": 12, "portion_size": "6oz chicken breast", "confidence": "mock"},
    {"name": "Fish Tacos", "cals": 480, "protein": 28, "carbs": 42, "fat": 22, "portion_size": "3 tacos", "confidence": "mock"},
    {"name": "Shrimp Scampi", "cals": 520, "protein": 32, "carbs": 48, "fat": 22, "portion_size": "1.5 cups with pasta", "confidence": "mock"},
    {"name": "Pork Chops with Rice", "cals": 540, "protein": 38, "carbs": 42, "fat": 24, "portion_size": "2 chops + 1 cup rice", "confidence": "mock"},
    {"name": "Vegetable Curry with Rice", "cals": 480, "protein": 14, "carbs": 62, "fat": 18, "portion_size": "2 cups curry + rice", "confidence": "mock"},
    {"name": "Meatloaf with Mashed Potatoes", "cals": 580, "protein": 32, "carbs": 42, "fat": 32, "portion_size": "2 slices + 1 cup potatoes", "confidence": "mock"},

    # Protein-focused meals
    {"name": "Grilled Chicken and Rice", "cals": 450, "protein": 40, "carbs": 45, "fat": 10, "portion_size": "6oz chicken + 1 cup rice", "confidence": "mock"},
    {"name": "Protein Shake", "cals": 250, "protein": 30, "carbs": 15, "fat": 6, "portion_size": "1 shake (16oz)", "confidence": "mock"},
    {"name": "Egg White Omelette", "cals": 180, "protein": 26, "carbs": 4, "fat": 6, "portion_size": "4 egg whites + veggies", "confidence": "mock"},
    {"name": "Lean Ground Turkey Bowl", "cals": 420, "protein": 38, "carbs": 35, "fat": 14, "portion_size": "6oz turkey + rice", "confidence": "mock"},
    {"name": "Cottage Cheese and Berries", "cals": 200, "protein": 24, "carbs": 18, "fat": 4, "portion_size": "1 cup cottage cheese", "confidence": "mock"},
    {"name": "Tuna Steak", "cals": 280, "protein": 45, "carbs": 0, "fat": 10, "portion_size": "6oz tuna steak", "confidence": "mock"},
    {"name": "Chicken Breast Salad", "cals": 320, "protein": 38, "carbs": 12, "fat": 14, "portion_size": "6oz chicken on greens", "confidence": "mock"},
    {"name": "Beef Jerky", "cals": 120, "protein": 18, "carbs": 6, "fat": 3, "portion_size": "1.5oz serving", "confidence": "mock"},
    {"name": "Hard Boiled Eggs", "cals": 210, "protein": 18, "carbs": 2, "fat": 14, "portion_size": "3 eggs", "confidence": "mock"},
    {"name": "Grilled Tilapia", "cals": 220, "protein": 36, "carbs": 0, "fat": 8, "portion_size": "6oz fillet", "confidence": "mock"},

    # Carb-focused meals
    {"name": "Spaghetti Bolognese", "cals": 620, "protein": 28, "carbs": 72, "fat": 24, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Rice and Beans", "cals": 380, "protein": 14, "carbs": 68, "fat": 4, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Baked Sweet Potato", "cals": 180, "protein": 4, "carbs": 42, "fat": 0, "portion_size": "1 large potato", "confidence": "mock"},
    {"name": "Whole Wheat Pasta Primavera", "cals": 420, "protein": 16, "carbs": 62, "fat": 12, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Quinoa Salad", "cals": 340, "protein": 12, "carbs": 48, "fat": 12, "portion_size": "1.5 cups", "confidence": "mock"},
    {"name": "Bagel with Cream Cheese", "cals": 380, "protein": 12, "carbs": 54, "fat": 14, "portion_size": "1 bagel", "confidence": "mock"},
    {"name": "Fried Rice", "cals": 480, "protein": 14, "carbs": 58, "fat": 20, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Mashed Potatoes", "cals": 240, "protein": 4, "carbs": 36, "fat": 10, "portion_size": "1 cup", "confidence": "mock"},
    {"name": "Garlic Bread", "cals": 280, "protein": 6, "carbs": 38, "fat": 12, "portion_size": "3 slices", "confidence": "mock"},
    {"name": "Corn on the Cob", "cals": 180, "protein": 6, "carbs": 36, "fat": 4, "portion_size": "2 ears", "confidence": "mock"},

    # Fast food items
    {"name": "Cheeseburger", "cals": 520, "protein": 28, "carbs": 42, "fat": 28, "portion_size": "1 burger", "confidence": "mock"},
    {"name": "Chicken Nuggets", "cals": 380, "protein": 22, "carbs": 24, "fat": 22, "portion_size": "10 pieces", "confidence": "mock"},
    {"name": "French Fries", "cals": 320, "protein": 4, "carbs": 42, "fat": 16, "portion_size": "medium serving", "confidence": "mock"},
    {"name": "Pizza Slice", "cals": 280, "protein": 12, "carbs": 32, "fat": 12, "portion_size": "1 large slice", "confidence": "mock"},
    {"name": "Hot Dog", "cals": 320, "protein": 12, "carbs": 28, "fat": 18, "portion_size": "1 hot dog", "confidence": "mock"},
    {"name": "Burrito Bowl", "cals": 580, "protein": 32, "carbs": 52, "fat": 26, "portion_size": "1 bowl", "confidence": "mock"},
    {"name": "Chicken Sandwich", "cals": 480, "protein": 28, "carbs": 44, "fat": 22, "portion_size": "1 sandwich", "confidence": "mock"},
    {"name": "Nachos with Cheese", "cals": 520, "protein": 14, "carbs": 48, "fat": 32, "portion_size": "1 plate", "confidence": "mock"},
    {"name": "Fried Chicken", "cals": 480, "protein": 32, "carbs": 18, "fat": 32, "portion_size": "2 pieces", "confidence": "mock"},
    {"name": "Sub Sandwich", "cals": 580, "protein": 32, "carbs": 58, "fat": 24, "portion_size": "12-inch sub", "confidence": "mock"},

    # Healthy/Light meals
    {"name": "Garden Salad", "cals": 120, "protein": 4, "carbs": 18, "fat": 4, "portion_size": "1 large bowl", "confidence": "mock"},
    {"name": "Steamed Vegetables", "cals": 80, "protein": 4, "carbs": 16, "fat": 1, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Grilled Fish", "cals": 220, "protein": 35, "carbs": 0, "fat": 8, "portion_size": "6oz fillet", "confidence": "mock"},
    {"name": "Vegetable Soup", "cals": 120, "protein": 4, "carbs": 22, "fat": 2, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Mixed Fruit Bowl", "cals": 180, "protein": 2, "carbs": 46, "fat": 1, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Hummus with Veggies", "cals": 220, "protein": 8, "carbs": 24, "fat": 12, "portion_size": "1/3 cup hummus + veggies", "confidence": "mock"},
    {"name": "Edamame", "cals": 180, "protein": 16, "carbs": 14, "fat": 8, "portion_size": "1 cup shelled", "confidence": "mock"},
    {"name": "Caprese Salad", "cals": 280, "protein": 14, "carbs": 8, "fat": 22, "portion_size": "1 plate", "confidence": "mock"},
    {"name": "Shrimp Cocktail", "cals": 140, "protein": 24, "carbs": 6, "fat": 2, "portion_size": "6 large shrimp", "confidence": "mock"},
    {"name": "Zucchini Noodles with Pesto", "cals": 240, "protein": 8, "carbs": 12, "fat": 18, "portion_size": "2 cups", "confidence": "mock"},

    # Snacks
    {"name": "Apple with Peanut Butter", "cals": 280, "protein": 8, "carbs": 34, "fat": 16, "portion_size": "1 apple + 2 tbsp PB", "confidence": "mock"},
    {"name": "Trail Mix", "cals": 320, "protein": 10, "carbs": 28, "fat": 20, "portion_size": "1/4 cup", "confidence": "mock"},
    {"name": "Protein Bar", "cals": 220, "protein": 20, "carbs": 24, "fat": 8, "portion_size": "1 bar", "confidence": "mock"},
    {"name": "Cheese and Crackers", "cals": 280, "protein": 12, "carbs": 22, "fat": 18, "portion_size": "2oz cheese + 6 crackers", "confidence": "mock"},
    {"name": "Mixed Nuts", "cals": 280, "protein": 8, "carbs": 12, "fat": 24, "portion_size": "1/4 cup", "confidence": "mock"},
    {"name": "Granola Bar", "cals": 180, "protein": 4, "carbs": 28, "fat": 7, "portion_size": "1 bar", "confidence": "mock"},
    {"name": "Rice Cakes with Almond Butter", "cals": 180, "protein": 5, "carbs": 22, "fat": 9, "portion_size": "2 cakes + 1 tbsp", "confidence": "mock"},
    {"name": "Banana", "cals": 105, "protein": 1, "carbs": 27, "fat": 0, "portion_size": "1 medium banana", "confidence": "mock"},
    {"name": "Popcorn", "cals": 140, "protein": 4, "carbs": 26, "fat": 4, "portion_size": "3 cups popped", "confidence": "mock"},
    {"name": "Dark Chocolate", "cals": 170, "protein": 2, "carbs": 18, "fat": 12, "portion_size": "1oz (28g)", "confidence": "mock"},

    # International cuisine
    {"name": "Pad Thai", "cals": 520, "protein": 22, "carbs": 58, "fat": 22, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Chicken Tikka Masala", "cals": 480, "protein": 32, "carbs": 28, "fat": 26, "portion_size": "1.5 cups", "confidence": "mock"},
    {"name": "Sushi Roll", "cals": 320, "protein": 14, "carbs": 48, "fat": 8, "portion_size": "8 pieces", "confidence": "mock"},
    {"name": "Beef Tacos", "cals": 420, "protein": 24, "carbs": 32, "fat": 22, "portion_size": "3 tacos", "confidence": "mock"},
    {"name": "Chicken Shawarma", "cals": 480, "protein": 35, "carbs": 32, "fat": 24, "portion_size": "1 wrap", "confidence": "mock"},
    {"name": "Falafel Plate", "cals": 520, "protein": 18, "carbs": 58, "fat": 24, "portion_size": "6 falafel + sides", "confidence": "mock"},
    {"name": "Bibimbap", "cals": 580, "protein": 28, "carbs": 68, "fat": 20, "portion_size": "1 large bowl", "confidence": "mock"},
    {"name": "Pho", "cals": 420, "protein": 28, "carbs": 48, "fat": 12, "portion_size": "1 large bowl", "confidence": "mock"},
    {"name": "Gyros", "cals": 520, "protein": 28, "carbs": 42, "fat": 28, "portion_size": "1 wrap", "confidence": "mock"},
    {"name": "Kung Pao Chicken", "cals": 420, "protein": 32, "carbs": 24, "fat": 22, "portion_size": "1.5 cups", "confidence": "mock"},

    # Beverages (with calories)
    {"name": "Latte", "cals": 190, "protein": 10, "carbs": 18, "fat": 8, "portion_size": "16oz", "confidence": "mock"},
    {"name": "Orange Juice", "cals": 110, "protein": 2, "carbs": 26, "fat": 0, "portion_size": "8oz", "confidence": "mock"},
    {"name": "Smoothie", "cals": 280, "protein": 6, "carbs": 52, "fat": 6, "portion_size": "16oz", "confidence": "mock"},
    {"name": "Chocolate Milk", "cals": 210, "protein": 8, "carbs": 28, "fat": 8, "portion_size": "8oz", "confidence": "mock"},
    {"name": "Energy Drink", "cals": 110, "protein": 0, "carbs": 28, "fat": 0, "portion_size": "8.4oz can", "confidence": "mock"},

    # Desserts
    {"name": "Ice Cream", "cals": 280, "protein": 5, "carbs": 32, "fat": 15, "portion_size": "1 cup", "confidence": "mock"},
    {"name": "Chocolate Chip Cookie", "cals": 160, "protein": 2, "carbs": 22, "fat": 8, "portion_size": "1 large cookie", "confidence": "mock"},
    {"name": "Brownie", "cals": 240, "protein": 3, "carbs": 32, "fat": 12, "portion_size": "1 piece", "confidence": "mock"},
    {"name": "Cheesecake", "cals": 380, "protein": 6, "carbs": 32, "fat": 26, "portion_size": "1 slice", "confidence": "mock"},
    {"name": "Fruit Salad", "cals": 120, "protein": 1, "carbs": 30, "fat": 0, "portion_size": "1 cup", "confidence": "mock"},

    # Additional gym-friendly meals
    {"name": "Chicken and Broccoli", "cals": 320, "protein": 38, "carbs": 12, "fat": 14, "portion_size": "6oz chicken + 2 cups broccoli", "confidence": "mock"},
    {"name": "Turkey Meatballs", "cals": 280, "protein": 32, "carbs": 8, "fat": 14, "portion_size": "6 meatballs", "confidence": "mock"},
    {"name": "Egg Fried Rice", "cals": 420, "protein": 16, "carbs": 52, "fat": 16, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Salmon Salad", "cals": 380, "protein": 32, "carbs": 12, "fat": 24, "portion_size": "4oz salmon on greens", "confidence": "mock"},
    {"name": "Chicken Caesar Wrap", "cals": 480, "protein": 32, "carbs": 38, "fat": 24, "portion_size": "1 wrap", "confidence": "mock"},
    {"name": "Steak Salad", "cals": 420, "protein": 36, "carbs": 14, "fat": 26, "portion_size": "5oz steak on greens", "confidence": "mock"},
    {"name": "Tuna Salad", "cals": 280, "protein": 28, "carbs": 8, "fat": 16, "portion_size": "1 cup", "confidence": "mock"},
    {"name": "Chicken Fried Rice", "cals": 480, "protein": 26, "carbs": 54, "fat": 18, "portion_size": "2 cups", "confidence": "mock"},
    {"name": "Beef and Vegetables", "cals": 380, "protein": 34, "carbs": 18, "fat": 20, "portion_size": "6oz beef + veggies", "confidence": "mock"},
    {"name": "Grilled Shrimp", "cals": 180, "protein": 32, "carbs": 2, "fat": 4, "portion_size": "8 large shrimp", "confidence": "mock"},
]
