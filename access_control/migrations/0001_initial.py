from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("auth", "0012_alter_user_first_name_max_length"),
    ]

    operations = [
        migrations.CreateModel(
            name="ApiEndpoint",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("name", models.CharField(max_length=255)),
                ("url_name", models.CharField(max_length=255)),
                ("path", models.CharField(max_length=255)),
                ("method", models.CharField(max_length=10)),
                ("description", models.TextField(blank=True)),
                ("is_active", models.BooleanField(default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={
                "ordering": ["path", "method"],
                "unique_together": {("url_name", "method")},
            },
        ),
        migrations.CreateModel(
            name="ApiAccessGrant",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("notes", models.TextField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("endpoint", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="grants", to="access_control.apiendpoint")),
                ("group", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name="api_access_grants", to="auth.group")),
                ("user", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name="api_access_grants", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["endpoint__path", "endpoint__method"],
            },
        ),
        migrations.AddConstraint(
            model_name="apiaccessgrant",
            constraint=models.CheckConstraint(
                check=(
                    (models.Q(group__isnull=True, user__isnull=False))
                    | (models.Q(group__isnull=False, user__isnull=True))
                ),
                name="api_access_grant_one_principal_chk",
            ),
        ),
        migrations.AddConstraint(
            model_name="apiaccessgrant",
            constraint=models.UniqueConstraint(
                condition=models.Q(("user__isnull", False)),
                fields=("endpoint", "user"),
                name="api_access_grant_unique_user",
            ),
        ),
        migrations.AddConstraint(
            model_name="apiaccessgrant",
            constraint=models.UniqueConstraint(
                condition=models.Q(("group__isnull", False)),
                fields=("endpoint", "group"),
                name="api_access_grant_unique_group",
            ),
        ),
    ]
