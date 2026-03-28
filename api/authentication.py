from dataclasses import dataclass

from django.contrib.auth.models import Group
from django.db import connection
from django.utils import timezone
from rest_framework import authentication
from rest_framework.exceptions import AuthenticationFailed

from api import models


@dataclass
class AppSessionUser:
    app_user: models.User

    @property
    def id(self):
        return self.app_user.id

    @property
    def anonymous_name(self):
        return self.app_user.anonymous_name

    @property
    def is_authenticated(self):
        return True

    @property
    def is_staff(self):
        return False

    @property
    def is_superuser(self):
        return False

    @property
    def is_app_user(self):
        return True

    @property
    def groups(self):
        return Group.objects.none()


def set_app_user_context(app_user_id):
    with connection.cursor() as cursor:
        cursor.execute("SELECT set_config('app.current_user_id', %s, false)", [str(app_user_id)])


class AppSessionAuthentication(authentication.BaseAuthentication):
    session_key = "app_user_id"

    def authenticate(self, request):
        app_user_id = request.session.get(self.session_key)
        if not app_user_id:
            return None
        try:
            app_user = models.User.objects.get(id=app_user_id, is_banned=False)
        except models.User.DoesNotExist as exc:
            raise AuthenticationFailed("App user session is invalid.") from exc
        set_app_user_context(app_user.id)
        return AppSessionUser(app_user), None


class AppTokenAuthentication(authentication.BaseAuthentication):
    keyword_values = {"bearer", "token"}

    def authenticate(self, request):
        auth_header = authentication.get_authorization_header(request).decode("utf-8").strip()
        if not auth_header:
            return None

        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() not in self.keyword_values:
            return None

        token_key = parts[1]
        try:
            token = models.AppUserToken.objects.get(key=token_key)
        except models.AppUserToken.DoesNotExist:
            return None

        try:
            app_user = models.User.objects.get(id=token.user_id, is_banned=False)
        except models.User.DoesNotExist as exc:
            raise AuthenticationFailed("App token is invalid.") from exc

        token.last_used_at = timezone.now()
        token.save(update_fields=["last_used_at", "updated_at"])
        set_app_user_context(app_user.id)
        return AppSessionUser(app_user), token
