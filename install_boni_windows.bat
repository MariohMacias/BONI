@echo off
REM Script de Instalación para B.O.N.I. AI en Windows
REM Este script guiará al usuario paso a paso para configurar y ejecutar el sistema B.O.N.I. AI.

REM --- Colores para la salida de la consola ---
REM No hay colores directos como en Bash, pero se pueden usar códigos ANSI si la terminal lo soporta (Windows 10+)
REM Para simplicidad, usaremos solo echo para mensajes.

:log_info
  echo [INFO] %*
goto :eof

:log_success
  echo [EXITO] %*
goto :eof

:log_warning
  echo [ADVERTENCIA] %*
goto :eof

:log_error
  echo [ERROR] %*
goto :eof

REM --- Función para pausar la ejecución ---
:press_any_key
  call :log_info 


Presiona cualquier tecla para continuar...
  pause >nul
goto :eof

REM --- Bienvenida ---
cls
call :log_info ======================================================
call :log_info   Bienvenido al Instalador de B.O.N.I. AI para Windows  
call :log_info ======================================================
call :log_info Este script te ayudará a instalar y configurar B.O.N.I. AI en tu sistema.
call :log_info Asegúrate de tener conexión a internet.
call :press_any_key

REM --- 1. Verificación de Prerrequisitos ---
call :log_info 
--- 1. Verificando Prerrequisitos ---

REM 1.1. Node.js y npm
call :log_info Verificando Node.js y npm...
where node >nul 2>&1
if %errorlevel% neq 0 (
  call :log_warning Node.js o npm no encontrados. Por favor, instálalos manualmente.
  call :log_info Descarga desde https://nodejs.org/es/download/
  call :log_error Luego de instalar, vuelve a ejecutar este script.
  call :press_any_key
  exit /b 1
) else (
  for /f "tokens=*" %%i in (
    'node -v'
  ) do set NODE_VERSION=%%i
  call :log_info Node.js y npm ya están instalados. Versión de Node.js: %NODE_VERSION%
)
call :press_any_key

REM 1.2. MongoDB
call :log_info Verificando MongoDB...
where mongod >nul 2>&1
if %errorlevel% neq 0 (
  call :log_warning MongoDB no encontrado. Por favor, instálalo manualmente.
  call :log_info Descarga desde https://www.mongodb.com/try/download/community
  call :log_error Luego de instalar, asegúrate de que el servicio de MongoDB esté corriendo y vuelve a ejecutar este script.
  call :press_any_key
  exit /b 1
) else (
  call :log_info MongoDB ya está instalado.
  REM Intentar iniciar el servicio de MongoDB si no está corriendo
  sc query MongoDB >nul 2>&1
  if %errorlevel% neq 0 (
    call :log_warning Servicio de MongoDB no encontrado. Asegúrate de que esté instalado correctamente.
  ) else (
    sc query MongoDB | find "STATE" | find "RUNNING" >nul
    if %errorlevel% neq 0 (
      call :log_warning Servicio de MongoDB no está activo. Intentando iniciarlo...
      net start MongoDB
      sc query MongoDB | find "STATE" | find "RUNNING" >nul
      if %errorlevel% neq 0 (
        call :log_error Fallo al iniciar el servicio de MongoDB. Por favor, verifícalo manualmente.
        call :press_any_key
        exit /b 1
      ) else (
        call :log_success Servicio de MongoDB iniciado correctamente.
      )
    ) else (
      call :log_success Servicio de MongoDB está activo y funcionando.
    )
  )
)
call :press_any_key

REM 1.3. Git
call :log_info Verificando Git...
where git >nul 2>&1
if %errorlevel% neq 0 (
  call :log_warning Git no encontrado. Por favor, instálalo manualmente.
  call :log_info Descarga desde https://git-scm.com/download/win
  call :log_error Luego de instalar, vuelve a ejecutar este script.
  call :press_any_key
  exit /b 1
) else (
  for /f "tokens=*" %%i in (
    'git --version'
  ) do set GIT_VERSION=%%i
  call :log_info Git ya está instalado. Versión de Git: %GIT_VERSION%
)
call :press_any_key

REM --- 2. Clonar el Repositorio de B.O.N.I. AI ---
call :log_info 
--- 2. Clonando el Repositorio de B.O.N.I. AI ---

set REPO_URL="https://github.com/your-repo/boni-ai.git" REM TODO: Reemplazar con la URL real del repositorio
set INSTALL_DIR=%CD%\boni-ai

if exist "%INSTALL_DIR%" (
  call :log_warning El directorio '%INSTALL_DIR%' ya existe. Saltando la clonación del repositorio.
  call :log_info Si deseas una instalación limpia, elimina el directorio '%INSTALL_DIR%' antes de ejecutar el script.
) else (
  call :log_info Clonando el repositorio desde %REPO_URL% en %INSTALL_DIR%...
  git clone %REPO_URL% "%INSTALL_DIR%"
  if %errorlevel% neq 0 (
    call :log_error Fallo al clonar el repositorio. Verifica la URL o tu conexión a internet.
    call :press_any_key
    exit /b 1
  )
  call :log_success Repositorio clonado exitosamente.
)
call :press_any_key

REM --- 3. Configuración del Backend ---
call :log_info 
--- 3. Configurando el Backend ---
set BACKEND_DIR=%INSTALL_DIR%\boni-backend

if not exist "%BACKEND_DIR%" (
  call :log_error Directorio del backend no encontrado: %BACKEND_DIR%. Asegúrate de que el repositorio se clonó correctamente.
  call :press_any_key
  exit /b 1
)

cd "%BACKEND_DIR%"

call :log_info Instalando dependencias del backend...
npm install
if %errorlevel% neq 0 (
  call :log_error Fallo al instalar las dependencias del backend. Por favor, revisa los errores.
  call :press_any_key
  exit /b 1
)
call :log_success Dependencias del backend instaladas exitosamente.

call :log_info Configurando variables de entorno del backend (.env)...
if not exist ".env" (
  copy .env.example .env >nul
  call :log_info Se ha creado un archivo .env básico. Por favor, edítalo con tus claves API y configuraciones.
  call :log_info Puedes editarlo con Notepad o tu editor de texto preferido.
  call :log_info Asegúrate de configurar MISTRAL_API_KEY y JWT_SECRET.
  call :press_any_key
) else (
  call :log_info El archivo .env ya existe. Si necesitas modificarlo, hazlo manualmente.
)

call :log_info Ejecutando migraciones de base de datos (si aplica)...
npm run migrate
if %errorlevel% neq 0 (
  call :log_warning Fallo al ejecutar las migraciones. Esto puede ser normal si no hay migraciones pendientes o si la base de datos ya está actualizada.
)
call :log_success Configuración del backend completada.
call :press_any_key

REM --- 4. Configuración del Frontend (Panel de Administración) ---
call :log_info 
--- 4. Configurando el Frontend (Panel de Administración) ---
set FRONTEND_DIR=%INSTALL_DIR%\boni-admin-panel
set FRONTEND_EXISTS=false

if exist "%FRONTEND_DIR%" (
  set FRONTEND_EXISTS=true
  cd "%FRONTEND_DIR%"
  call :log_info Instalando dependencias del frontend...
  npm install
  if %errorlevel% neq 0 (
    call :log_error Fallo al instalar las dependencias del frontend. Por favor, revisa los errores.
    call :press_any_key
    exit /b 1
  )
  call :log_success Dependencias del frontend instaladas exitosamente.
  call :log_success Configuración del frontend completada.
) else (
  call :log_warning Directorio del frontend no encontrado: %FRONTEND_DIR%. Asumiendo que el frontend se manejará por separado o no es necesario para esta instalación.
  call :log_info Si el frontend existe, asegúrate de que el repositorio lo incluya o clónalo manualmente.
)
call :press_any_key

REM --- 5. Inicio del Sistema ---
call :log_info 
--- 5. Iniciando el Sistema B.O.N.I. AI ---

call :log_info Iniciando el backend de B.O.N.I. AI...
start "B.O.N.I. Backend" cmd /k "cd /d "%BACKEND_DIR%" && npm start"

if "%FRONTEND_EXISTS%" == "true" (
  call :log_info Iniciando el frontend (Panel de Administración) de B.O.N.I. AI...
  start "B.O.N.I. Frontend" cmd /k "cd /d "%FRONTEND_DIR%" && npm run dev -- --host"
) else (
  call :log_warning Frontend no encontrado, no se iniciará.
)

call :log_info Esperando unos segundos para que los servicios se inicien completamente...
ping -n 11 127.0.0.1 > nul

call :log_success ¡Instalación y configuración de B.O.N.I. AI completadas!
call :log_info 
--- Información Importante ---
call :log_info Backend de B.O.N.I. AI debería estar accesible en: http://localhost:3001
if "%FRONTEND_EXISTS%" == "true" (
  call :log_info Panel de Administración de B.O.N.I. AI debería estar accesible en: http://localhost:5173
) else (
  call :log_warning Recuerda que el frontend no se inició. Si lo necesitas, instálalo y ejecútalo manualmente.
)
call :log_info Para detener los servicios, cierra las ventanas de consola que se abrieron.
call :log_info ¡Disfruta de B.O.N.I. AI!

exit /b 0


