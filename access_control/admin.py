from django.contrib import admin

from access_control.models import ApiAccessGrant, ApiEndpoint


@admin.register(ApiEndpoint)
class ApiEndpointAdmin(admin.ModelAdmin):
    list_display = ("name", "method", "path", "url_name", "is_active", "updated_at")
    list_filter = ("method", "is_active")
    search_fields = ("name", "path", "url_name", "description")


@admin.register(ApiAccessGrant)
class ApiAccessGrantAdmin(admin.ModelAdmin):
    list_display = ("endpoint", "user", "group", "created_at")
    list_filter = ("endpoint__method",)
    search_fields = ("endpoint__path", "user__username", "group__name", "notes")
