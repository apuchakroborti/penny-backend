from django.urls import include, path
from rest_framework.routers import DefaultRouter

from api.auth_views import AppLoginView, AppLogoutView, AppMeView
from api.registry import API_ENDPOINTS

router = DefaultRouter()

for endpoint in API_ENDPOINTS:
    router.register(endpoint["prefix"], endpoint["viewset"], basename=endpoint["basename"])

urlpatterns = [
    path("login/", AppLoginView.as_view(), name="app-login"),
    path("me/", AppMeView.as_view(), name="app-me"),
    path("logout/", AppLogoutView.as_view(), name="app-logout"),
    path("", include(router.urls)),
]
