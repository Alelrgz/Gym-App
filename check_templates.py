import os
from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError

def check_templates():
    template_dir = "templates"
    env = Environment(loader=FileSystemLoader(template_dir))
    
    templates_to_check = [
        "base.html",
        "client.html", 
        "trainer.html", 
        "owner.html",
        "login.html",
        "register.html",
        "macros.html",
        "modals.html"
    ]
    
    print(f"Checking templates in {template_dir}...")
    
    has_errors = False
    
    for template_name in templates_to_check:
        try:
            # Just trying to load the template parses it and checks for syntax errors
            template = env.get_template(template_name)
            print(f"[OK] {template_name} - Syntax OK")
            
        except TemplateSyntaxError as e:
            print(f"[FAIL] {template_name} - SYNTAX ERROR")
            print(f"   Line {e.lineno}: {e.message}")
            has_errors = True
        except Exception as e:
            print(f"[FAIL] {template_name} - ERROR: {e}")
            has_errors = True
            
    if has_errors:
        print("\nFound template errors! Please fix them.")
    else:
        print("\nAll templates passed syntax check.")

if __name__ == "__main__":
    check_templates()
