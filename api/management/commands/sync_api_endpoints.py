from django.core.management.base import BaseCommand

from access_control.models import ApiEndpoint
from api.registry import API_ENDPOINTS


class Command(BaseCommand):
    help = "Sync the API endpoint catalog used by the Django admin access-control screens."

    def handle(self, *args, **options):
        active_ids = []
        for endpoint in API_ENDPOINTS:
            list_name = f"{endpoint['basename']}-list"
            detail_name = f"{endpoint['basename']}-detail"
            viewset = endpoint["viewset"]
            list_methods = ["GET"]
            detail_methods = ["GET"]

            if "post" in viewset.http_method_names:
                list_methods.append("POST")
            for method in ("put", "patch", "delete"):
                if method in viewset.http_method_names:
                    detail_methods.append(method.upper())

            for url_name, methods in ((list_name, list_methods), (detail_name, detail_methods)):
                for method in methods:
                    record, _ = ApiEndpoint.objects.update_or_create(
                        url_name=url_name,
                        method=method,
                        defaults={
                            "name": f"{endpoint['basename']} {method}",
                            "path": f"/api/{endpoint['prefix']}/",
                            "description": endpoint["description"],
                            "is_active": True,
                        },
                    )
                    active_ids.append(record.pk)

        ApiEndpoint.objects.exclude(pk__in=active_ids).update(is_active=False)

        self.stdout.write(self.style.SUCCESS("API endpoint registry synchronized."))
