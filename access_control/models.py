from django.contrib.auth.models import Group, User
from django.db import models
from django.db.models import Q


class ApiEndpoint(models.Model):
    name = models.CharField(max_length=255)
    url_name = models.CharField(max_length=255)
    path = models.CharField(max_length=255)
    method = models.CharField(max_length=10)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["path", "method"]
        unique_together = ("url_name", "method")

    def __str__(self):
        return f"{self.method} {self.path}"


class ApiAccessGrant(models.Model):
    endpoint = models.ForeignKey(ApiEndpoint, on_delete=models.CASCADE, related_name="grants")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="api_access_grants", blank=True, null=True)
    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="api_access_grants", blank=True, null=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["endpoint__path", "endpoint__method"]
        constraints = [
            models.CheckConstraint(
                check=(
                    (Q(user__isnull=False) & Q(group__isnull=True))
                    | (Q(user__isnull=True) & Q(group__isnull=False))
                ),
                name="api_access_grant_one_principal_chk",
            ),
            models.UniqueConstraint(
                fields=["endpoint", "user"],
                condition=Q(user__isnull=False),
                name="api_access_grant_unique_user",
            ),
            models.UniqueConstraint(
                fields=["endpoint", "group"],
                condition=Q(group__isnull=False),
                name="api_access_grant_unique_group",
            ),
        ]

    def __str__(self):
        principal = self.user.username if self.user else self.group.name
        return f"{principal} -> {self.endpoint}"
