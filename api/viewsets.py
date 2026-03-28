import uuid

from django.db import connection
from django.db import IntegrityError
from django.utils import timezone
from rest_framework import status
from rest_framework import filters, viewsets
from rest_framework.response import Response

from access_control.permissions import EndpointAccessPermission
from api import models, serializers


class ManagedModelViewSet(viewsets.ModelViewSet):
    permission_classes = [EndpointAccessPermission]
    filter_backends = [filters.OrderingFilter, filters.SearchFilter]
    ordering = ["-id"]


class ReadOnlyManagedModelViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [EndpointAccessPermission]
    filter_backends = [filters.OrderingFilter, filters.SearchFilter]


class UserViewSet(ManagedModelViewSet):
    allow_public_read = True
    allow_public_create = True
    allow_app_authenticated = True
    queryset = models.User.objects.all()
    serializer_class = serializers.UserSerializer
    ordering = ["-created_at"]
    search_fields = ["anonymous_name", "current_mood"]

    def perform_create(self, serializer):
        new_user_id = serializer.validated_data.get("id") or uuid.uuid4()
        now = timezone.now()
        with connection.cursor() as cursor:
            cursor.execute("SELECT set_config('app.current_user_id', %s, false)", [str(new_user_id)])
        try:
            serializer.save(
                id=new_user_id,
                is_premium=False,
                premium_expires_at=None,
                is_banned=False,
                created_at=now,
                updated_at=now,
            )
        finally:
            with connection.cursor() as cursor:
                cursor.execute("SELECT set_config('app.current_user_id', %s, false)", [""])

    def get_queryset(self):
        user = getattr(self.request, "user", None)
        if getattr(user, "is_app_user", False):
            return models.User.objects.filter(id=user.id)
        return super().get_queryset()


class UserTagViewSet(ManagedModelViewSet):
    allow_app_authenticated = True
    queryset = models.UserTag.objects.select_related("user").all()
    serializer_class = serializers.UserTagSerializer
    ordering = ["tag"]
    search_fields = ["tag"]

    def get_queryset(self):
        user = getattr(self.request, "user", None)
        if getattr(user, "is_app_user", False):
            return models.UserTag.objects.select_related("user").filter(user_id=user.id)
        return super().get_queryset()

    def perform_create(self, serializer):
        user = getattr(self.request, "user", None)
        if getattr(user, "is_app_user", False):
            serializer.save(user_id=user.id, created_at=timezone.now())
            return
        serializer.save(created_at=timezone.now())


class WishViewSet(ManagedModelViewSet):
    queryset = models.Wish.objects.select_related("user").all()
    serializer_class = serializers.WishSerializer
    ordering = ["-created_at"]
    search_fields = ["content", "ai_refined_content", "moderation_flag"]


class WishTagViewSet(ManagedModelViewSet):
    queryset = models.WishTag.objects.select_related("wish").all()
    serializer_class = serializers.WishTagSerializer
    ordering = ["tag"]
    search_fields = ["tag"]


class WishReplyViewSet(ManagedModelViewSet):
    allow_app_authenticated = True
    queryset = models.WishReply.objects.select_related("wish", "author_user", "parent_reply").all()
    serializer_class = serializers.WishReplySerializer
    ordering = ["created_at", "id"]
    search_fields = ["content", "author_user__anonymous_name"]

    def get_queryset(self):
        queryset = super().get_queryset()
        params = self.request.query_params

        wish_id = params.get("wish")
        parent_reply_id = params.get("parent_reply")

        if wish_id:
            queryset = queryset.filter(wish_id=wish_id)
        if parent_reply_id:
            queryset = queryset.filter(parent_reply_id=parent_reply_id)

        return queryset

    def perform_create(self, serializer):
        user = getattr(self.request, "user", None)
        if not getattr(user, "is_app_user", False):
            reply = serializer.save(created_at=timezone.now(), updated_at=timezone.now())
            self._create_reply_notifications(reply)
            return
        reply = serializer.save(author_user_id=user.id, created_at=timezone.now(), updated_at=timezone.now())
        self._create_reply_notifications(reply)

    def perform_update(self, serializer):
        serializer.save(updated_at=timezone.now())

    def _create_reply_notifications(self, reply):
        now = timezone.now()
        recipients = []

        if reply.parent_reply_id:
            if reply.parent_reply.author_user_id != reply.author_user_id:
                recipients.append(
                    (
                        reply.parent_reply.author_user_id,
                        models.NotificationType.WISH_REPLY_REPLY,
                        "Someone replied to your reply",
                        "A new reply arrived on your write-back.",
                    )
                )
        elif reply.wish.user_id != reply.author_user_id:
            recipients.append(
                (
                    reply.wish.user_id,
                    models.NotificationType.WISH_REPLY,
                    "Someone wrote back to your wish",
                    "A new public write-back was added to your wish.",
                )
            )

        for user_id, notification_type, title, body in recipients:
            models.Notification.objects.create(
                user_id=user_id,
                type=notification_type,
                title=title,
                body=body,
                is_read=False,
                related_entity_id=reply.id,
                created_at=now,
            )


class InteractionViewSet(ManagedModelViewSet):
    allow_app_authenticated = True
    queryset = models.Interaction.objects.select_related("actor_user", "target_wish").all()
    serializer_class = serializers.InteractionSerializer
    ordering = ["-created_at"]
    search_fields = ["type"]

    def get_queryset(self):
        queryset = super().get_queryset()
        params = self.request.query_params

        target_wish_id = params.get("target_wish")
        actor_user_id = params.get("actor_user")
        interaction_type = params.get("type")

        if target_wish_id:
            queryset = queryset.filter(target_wish_id=target_wish_id)
        if actor_user_id:
            queryset = queryset.filter(actor_user_id=actor_user_id)
        if interaction_type:
            queryset = queryset.filter(type=interaction_type)

        return queryset

    def perform_create(self, serializer):
        user = getattr(self.request, "user", None)
        if getattr(user, "is_app_user", False):
            serializer.save(actor_user_id=user.id, created_at=timezone.now())
            return
        serializer.save(created_at=timezone.now())

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            self.perform_create(serializer)
        except IntegrityError:
            return Response(
                {"detail": "This interaction already exists for the actor, wish, and type."},
                status=status.HTTP_409_CONFLICT,
            )

        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)


class MatchViewSet(ManagedModelViewSet):
    queryset = models.Match.objects.all()
    serializer_class = serializers.MatchSerializer
    ordering = ["-created_at"]
    search_fields = ["match_status"]


class ConversationViewSet(ManagedModelViewSet):
    queryset = models.Conversation.objects.select_related("match").all()
    serializer_class = serializers.ConversationSerializer
    ordering = ["-created_at"]


class MessageViewSet(ManagedModelViewSet):
    queryset = models.Message.objects.select_related("conversation", "sender_user").all()
    serializer_class = serializers.MessageSerializer
    ordering = ["-sent_at"]
    search_fields = ["content"]


class EmotionalPatternViewSet(ManagedModelViewSet):
    queryset = models.EmotionalPattern.objects.select_related("user").all()
    serializer_class = serializers.EmotionalPatternSerializer
    ordering = ["-updated_at"]
    search_fields = ["dominant_emotion"]


class ModerationLogViewSet(ManagedModelViewSet):
    queryset = models.ModerationLog.objects.select_related("wish", "message").all()
    serializer_class = serializers.ModerationLogSerializer
    ordering = ["-created_at"]
    search_fields = ["reason", "triggered_by", "action_taken"]


class ReportViewSet(ManagedModelViewSet):
    queryset = models.Report.objects.select_related(
        "reporter_user",
        "reported_user",
        "reported_wish",
        "reported_message",
    ).all()
    serializer_class = serializers.ReportSerializer
    ordering = ["-created_at"]
    search_fields = ["reason", "status"]


class BlockViewSet(ManagedModelViewSet):
    queryset = models.Block.objects.select_related("blocker_user", "blocked_user").all()
    serializer_class = serializers.BlockSerializer
    ordering = ["-created_at"]


class NotificationViewSet(ManagedModelViewSet):
    allow_app_authenticated = True
    queryset = models.Notification.objects.select_related("user").all()
    serializer_class = serializers.NotificationSerializer
    ordering = ["-created_at"]
    search_fields = ["title", "body", "type"]

    def get_queryset(self):
        queryset = super().get_queryset()
        params = self.request.query_params
        user = getattr(self.request, "user", None)

        if getattr(user, "is_app_user", False):
            queryset = queryset.filter(user_id=user.id)

        is_read = params.get("is_read")
        if is_read is not None:
            normalized = is_read.strip().lower()
            if normalized in {"true", "1", "yes"}:
                queryset = queryset.filter(is_read=True)
            elif normalized in {"false", "0", "no"}:
                queryset = queryset.filter(is_read=False)

        return queryset


class SubscriptionViewSet(ManagedModelViewSet):
    queryset = models.Subscription.objects.select_related("user").all()
    serializer_class = serializers.SubscriptionSerializer
    ordering = ["-created_at"]
    search_fields = ["plan", "stripe_subscription_id"]


class AuraCustomizationViewSet(ManagedModelViewSet):
    queryset = models.AuraCustomization.objects.select_related("user").all()
    serializer_class = serializers.AuraCustomizationSerializer
    ordering = ["-updated_at"]
    search_fields = ["glow_color", "particle_style", "animation_speed"]


class PublicWishFeedViewSet(ReadOnlyManagedModelViewSet):
    allow_public_read = True
    queryset = models.PublicWishFeed.objects.all()
    serializer_class = serializers.PublicWishFeedSerializer
    ordering = ["-created_at"]
    search_fields = ["anonymous_name", "display_content", "emotion_label"]


class UserEmotionalSummaryViewSet(ReadOnlyManagedModelViewSet):
    queryset = models.UserEmotionalSummary.objects.all()
    serializer_class = serializers.UserEmotionalSummarySerializer
    ordering = ["anonymous_name"]
    search_fields = ["anonymous_name", "dominant_emotion", "current_mood"]


class ActiveMatchViewSet(ReadOnlyManagedModelViewSet):
    queryset = models.ActiveMatch.objects.all()
    serializer_class = serializers.ActiveMatchSerializer
    ordering = ["-created_at"]
    search_fields = ["anonymous_name_a", "anonymous_name_b"]


class MatchGraphViewSet(ReadOnlyManagedModelViewSet):
    queryset = models.MatchGraph.objects.all()
    serializer_class = serializers.MatchGraphSerializer
    ordering = ["-created_at"]
    search_fields = ["node_a_name", "node_b_name", "match_status"]
