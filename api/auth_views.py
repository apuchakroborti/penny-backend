from django.contrib.auth import logout
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from api import models
from api.serializers import AppLoginResponseSerializer, AppLoginSerializer, AppMeSerializer


class AppLoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = AppLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data["user"]
        request.session["app_user_id"] = str(user.id)
        request.session.modified = True
        token, _ = models.AppUserToken.objects.get_or_create(user_id=user.id)
        response = AppLoginResponseSerializer(
            {
                "authenticated": True,
                "token": token.key,
                "user_id": user.id,
                "anonymous_name": user.anonymous_name,
                "intent": user.intent,
                "current_mood": user.current_mood,
                "is_premium": user.is_premium,
            }
        )
        return Response(response.data, status=status.HTTP_200_OK)


class AppMeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user.app_user if getattr(request.user, "is_app_user", False) else None
        if user is None:
            return Response({"detail": "App user authentication required."}, status=status.HTTP_403_FORBIDDEN)
        payload = AppMeSerializer(
            {
                "user_id": user.id,
                "anonymous_name": user.anonymous_name,
                "intent": user.intent,
                "current_mood": user.current_mood,
                "is_premium": user.is_premium,
                "premium_expires_at": user.premium_expires_at,
            }
        )
        return Response(payload.data, status=status.HTTP_200_OK)


class AppLogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        auth = getattr(request, "auth", None)
        if isinstance(auth, models.AppUserToken):
            auth.delete()
        request.session.pop("app_user_id", None)
        logout(request)
        return Response(status=status.HTTP_204_NO_CONTENT)
