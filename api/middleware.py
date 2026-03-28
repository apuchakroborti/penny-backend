from django.db import connection


class DatabaseUserContextMiddleware:
    header_name = "HTTP_X_CURRENT_USER_ID"

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        current_user_id = request.META.get(self.header_name, "").strip()
        if not current_user_id:
            current_user_id = str(request.session.get("app_user_id", "")).strip()
        with connection.cursor() as cursor:
            cursor.execute("SELECT set_config('app.current_user_id', %s, false)", [current_user_id])
        try:
            return self.get_response(request)
        finally:
            with connection.cursor() as cursor:
                cursor.execute("SELECT set_config('app.current_user_id', %s, false)", [""])
