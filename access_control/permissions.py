from rest_framework.permissions import SAFE_METHODS, BasePermission

from access_control.models import ApiAccessGrant, ApiEndpoint


class EndpointAccessPermission(BasePermission):
    message = "You do not have access to this API endpoint."

    def has_permission(self, request, view):
        if request.method in SAFE_METHODS and getattr(view, "allow_public_read", False):
            return True
        if request.method == "POST" and getattr(view, "allow_public_create", False):
            return True

        user = request.user
        if not user or not user.is_authenticated:
            return False
        if getattr(user, "is_app_user", False) and getattr(view, "allow_app_authenticated", False):
            return True
        if user.is_staff or user.is_superuser:
            return True

        match = request.resolver_match
        if match is None or not match.url_name:
            return False

        method = "GET" if request.method in {"HEAD", "OPTIONS"} else request.method

        try:
            endpoint = ApiEndpoint.objects.get(url_name=match.url_name, method=method, is_active=True)
        except ApiEndpoint.DoesNotExist:
            return False

        group_ids = user.groups.values_list("id", flat=True)
        return ApiAccessGrant.objects.filter(endpoint=endpoint).filter(user=user).exists() or ApiAccessGrant.objects.filter(endpoint=endpoint, group_id__in=group_ids).exists()

    def has_object_permission(self, request, view, obj):
        user = request.user
        if getattr(user, "is_app_user", False) and getattr(view, "allow_app_authenticated", False):
            app_user_id = user.id
            if hasattr(obj, "id") and str(obj.id) == str(app_user_id):
                return True
            if hasattr(obj, "user_id") and str(obj.user_id) == str(app_user_id):
                return True
            return False
        return True
