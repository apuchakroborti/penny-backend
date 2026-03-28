from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="AppUserToken",
            fields=[
                ("key", models.CharField(editable=False, max_length=64, primary_key=True, serialize=False)),
                ("user_id", models.UUIDField(db_index=True, unique=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("last_used_at", models.DateTimeField(blank=True, null=True)),
            ],
            options={
                "ordering": ["-updated_at"],
            },
        ),
    ]
