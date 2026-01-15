try:
    import services
    print("Import successful")
except Exception as e:
    print(f"Import failed: {e}")
except SystemExit as e:
    print(f"SystemExit: {e}")
