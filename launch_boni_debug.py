import sys, os, traceback
sys.path.insert(0, r'C:\Users\nosoy\OneDrive\Desktop\boni')

try:
    from boni_ui import BONIWindow
    print("BONIWindow imported OK")
    
    from PyQt6.QtWidgets import QApplication
    app = QApplication(sys.argv)
    print("QApplication created OK")
    
    w = BONIWindow()
    print("BONIWindow instance OK")
    
    w.show()
    print("Window shown OK - entering event loop")
    sys.exit(app.exec())
except Exception as e:
    traceback.print_exc()
    with open(r'C:\Users\nosoy\AppData\Local\Temp\boni_error.log', 'w') as f:
        traceback.print_exc(file=f)
    print(f"FATAL: {e}")
    sys.exit(1)
