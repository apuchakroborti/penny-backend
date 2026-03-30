import hashlib
import re

from django.contrib.auth.hashers import check_password, identify_hasher, make_password
from rest_framework import serializers

from api import models


class HexBinaryField(serializers.Field):
    def to_representation(self, value):
        return value.hex() if value is not None else None

    def to_internal_value(self, data):
        if data in (None, ""):
            return None
        try:
            return bytes.fromhex(data)
        except ValueError as exc:
            raise serializers.ValidationError("Expected a hex-encoded string.") from exc


class BaseModelSerializer(serializers.ModelSerializer):
    class Meta:
        fields = "__all__"


class UserSerializer(BaseModelSerializer):
    email = serializers.EmailField(write_only=True, required=False)
    email_hash = HexBinaryField(required=False)

    class Meta(BaseModelSerializer.Meta):
        model = models.User
        read_only_fields = ("id", "is_premium", "premium_expires_at", "is_banned", "created_at", "updated_at")
        extra_kwargs = {
            "current_mood": {"required": False, "allow_null": True},
            "password_hash": {"write_only": True},
            "email_hash": {"required": False},
        }

    def validate_anonymous_name(self, value):
        normalized = (value or "").strip()
        if re.fullmatch(r"^[A-Za-z]+_[A-Za-z0-9]{2,12}$", normalized):
            return normalized

        letters_only = re.sub(r"[^A-Za-z]", "", normalized) or "Echo"
        suffix_seed = re.sub(r"[^A-Za-z0-9]", "", normalized).upper()[-6:] or "01"
        suffix = suffix_seed[:12]
        if len(suffix) < 2:
            suffix = suffix.ljust(2, "0")
        return f"{letters_only}_{suffix}"

    def validate_password_hash(self, value):
        try:
            identify_hasher(value)
            return value
        except Exception:
            return make_password(value)

    def validate(self, attrs):
        email = attrs.pop("email", None)
        if email:
            attrs["email_hash"] = AppLoginSerializer.build_email_hash(email)
        if self.instance:
            return attrs
        if not attrs.get("email_hash"):
            raise serializers.ValidationError({"email": "Provide email or email_hash."})
        return attrs


class AppLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(trim_whitespace=False)

    @staticmethod
    def normalize_email(email):
        return (email or "").strip().lower()

    @classmethod
    def build_email_hash(cls, email):
        return hashlib.sha256(cls.normalize_email(email).encode("utf-8")).digest()

    @staticmethod
    def verify_password(raw_password, stored_password_hash):
        if not stored_password_hash:
            return False
        try:
            return check_password(raw_password, stored_password_hash)
        except Exception:
            return raw_password == stored_password_hash

    def validate(self, attrs):
        email_hash = self.build_email_hash(attrs["email"])
        try:
            user = models.User.objects.get(email_hash=email_hash, is_banned=False)
        except models.User.DoesNotExist as exc:
            raise serializers.ValidationError("Invalid email or password.") from exc

        if not self.verify_password(attrs["password"], user.password_hash):
            raise serializers.ValidationError("Invalid email or password.")

        attrs["user"] = user
        return attrs


class AppLoginResponseSerializer(serializers.Serializer):
    authenticated = serializers.BooleanField()
    token = serializers.CharField()
    user_id = serializers.UUIDField()
    anonymous_name = serializers.CharField()
    intent = serializers.CharField()
    current_mood = serializers.CharField(allow_null=True)
    is_premium = serializers.BooleanField()


class AppMeSerializer(serializers.Serializer):
    user_id = serializers.UUIDField()
    anonymous_name = serializers.CharField()
    intent = serializers.CharField()
    current_mood = serializers.CharField(allow_null=True)
    is_premium = serializers.BooleanField()
    premium_expires_at = serializers.DateTimeField(allow_null=True)


class UserTagSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.UserTag
        read_only_fields = ("id", "created_at")
        extra_kwargs = {
            "user": {"required": False},
        }

    def validate_tag(self, value):
        return (value or "").strip().lower()


class WishSerializer(BaseModelSerializer):
    embedding = serializers.ListField(child=serializers.FloatField(), required=False, allow_null=True)

    class Meta(BaseModelSerializer.Meta):
        model = models.Wish
        read_only_fields = ("id", "user", "resonance_count", "created_at", "updated_at")


class WishTagSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.WishTag


class WishReplySerializer(BaseModelSerializer):
    author_anonymous_name = serializers.CharField(source="author_user.anonymous_name", read_only=True)

    class Meta(BaseModelSerializer.Meta):
        model = models.WishReply
        read_only_fields = ("id", "author_user", "author_anonymous_name", "created_at", "updated_at")
        extra_kwargs = {
            "parent_reply": {"required": False, "allow_null": True},
        }

    def validate_content(self, value):
        normalized = (value or "").strip()
        if not normalized:
            raise serializers.ValidationError("This field may not be blank.")
        return normalized

    def validate(self, attrs):
        wish = attrs.get("wish") or getattr(self.instance, "wish", None)
        parent_reply = attrs.get("parent_reply")
        if wish and (wish.visibility != models.WishVisibility.PUBLIC or wish.is_moderated):
            raise serializers.ValidationError({"wish": "Replies can only be added to public, unmoderated wishes."})
        if parent_reply and wish and parent_reply.wish_id != wish.id:
            raise serializers.ValidationError({"parent_reply": "Parent reply must belong to the same wish."})
        return attrs


class InteractionSerializer(BaseModelSerializer):
    actor_user_anonymous_name = serializers.CharField(source="actor_user.anonymous_name", read_only=True)

    class Meta(BaseModelSerializer.Meta):
        model = models.Interaction
        read_only_fields = ("id", "created_at", "actor_user_anonymous_name")
        extra_kwargs = {
            "actor_user": {"required": False},
        }


class MatchSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.Match


class ConversationSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.Conversation


class MessageSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.Message


class EmotionalPatternSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.EmotionalPattern


class ModerationLogSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.ModerationLog


class ReportSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.Report


class BlockSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.Block


class NotificationSerializer(BaseModelSerializer):
    wish_id = serializers.SerializerMethodField()
    reply_id = serializers.SerializerMethodField()
    actor_user = serializers.SerializerMethodField()
    actor_anonymous_name = serializers.SerializerMethodField()

    class Meta(BaseModelSerializer.Meta):
        model = models.Notification
        read_only_fields = (
            "id",
            "user",
            "type",
            "title",
            "body",
            "created_at",
            "related_entity_id",
            "wish_id",
            "reply_id",
            "actor_user",
            "actor_anonymous_name",
        )

    def _get_related_reply(self, obj):
        if not obj.related_entity_id:
            return None
        if obj.type not in {models.NotificationType.WISH_REPLY, models.NotificationType.WISH_REPLY_REPLY}:
            return None
        return models.WishReply.objects.select_related("author_user").filter(id=obj.related_entity_id).first()

    def _get_related_interaction(self, obj):
        if not obj.related_entity_id or obj.type != models.NotificationType.RESONANCE:
            return None
        return (
            models.Interaction.objects.select_related("actor_user")
            .filter(target_wish_id=obj.related_entity_id, type=models.InteractionType.RESONATE)
            .filter(created_at__lte=obj.created_at)
            .order_by("-created_at")
            .first()
        )

    def get_wish_id(self, obj):
        reply = self._get_related_reply(obj)
        if reply is not None:
            return str(reply.wish_id)
        if obj.type == models.NotificationType.RESONANCE and obj.related_entity_id:
            return str(obj.related_entity_id)
        return None

    def get_reply_id(self, obj):
        reply = self._get_related_reply(obj)
        return str(reply.id) if reply is not None else None

    def get_actor_user(self, obj):
        reply = self._get_related_reply(obj)
        if reply is not None:
            return str(reply.author_user_id)
        interaction = self._get_related_interaction(obj)
        return str(interaction.actor_user_id) if interaction is not None else None

    def get_actor_anonymous_name(self, obj):
        reply = self._get_related_reply(obj)
        if reply is not None:
            return reply.author_user.anonymous_name
        interaction = self._get_related_interaction(obj)
        return interaction.actor_user.anonymous_name if interaction is not None else None


class SubscriptionSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.Subscription


class AuraCustomizationSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.AuraCustomization


class PublicWishFeedSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.PublicWishFeed
        fields = "__all__"


class UserEmotionalSummarySerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.UserEmotionalSummary
        fields = "__all__"


class ActiveMatchSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.ActiveMatch
        fields = "__all__"


class MatchGraphSerializer(BaseModelSerializer):
    class Meta(BaseModelSerializer.Meta):
        model = models.MatchGraph
        fields = "__all__"
