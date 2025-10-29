@echo off
echo Starting FriendlyI Application with Docker...

echo.
echo Building and starting containers...
docker-compose up --build -d

echo.
echo Waiting for services to start...
timeout /t 30 /nobreak > nul

echo.
echo Checking service status...
docker-compose ps

echo.
echo Application URLs:
echo Frontend: http://localhost
echo Backend API: http://localhost:8080
echo Backend Health: http://localhost:8080/actuator/health

echo.
echo To view logs:
echo   docker-compose logs -f
echo.
echo To stop services:
echo   docker-compose down
echo.
echo Services are starting up. Please wait a moment before accessing the application.

pause