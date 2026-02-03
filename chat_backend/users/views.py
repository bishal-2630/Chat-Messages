from rest_framework import generics
from django.contrib.auth.models import User
from .models import Message
from .serializers import UserSerializer, UserListSerializer, MessageSerializer, ProfileSerializer
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.db.models import Q
from .mqtt import publish_message
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db import connection

class CustomAuthToken(ObtainAuthToken):
    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(data=request.data,
                                           context={'request': request})
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        token, created = Token.objects.get_or_create(user=user)
        return Response({
            'token': token.key,
            'user_id': user.pk,
            'email': user.email
        })

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = UserSerializer

class UserListView(generics.ListAPIView):
    serializer_class = UserListSerializer
    permission_classes = (IsAuthenticated,)

    def get_queryset(self):
        return User.objects.exclude(id=self.request.user.id)

class MessageListCreateView(generics.ListCreateAPIView):
    serializer_class = MessageSerializer
    permission_classes = (IsAuthenticated,)

    def get_queryset(self):
        try:
            other_user_id = self.request.query_params.get('user_id')
            
            if not other_user_id:
                return Message.objects.none()
            
            return Message.objects.filter(
                Q(sender=self.request.user, receiver_id=other_user_id) |
                Q(receiver=self.request.user, sender_id=other_user_id)
            ).order_by('timestamp')
        except Exception as e:
            # Re-raise for now if DEBUG is True, otherwise return helpful error
            # This is specifically to help debug the 500 error shown in the UI
            from django.conf import settings
            if settings.DEBUG:
                raise e
            # Log the error here in a real app
            print(f"Error in MessageListCreateView: {e}")
            return Message.objects.none()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        message = serializer.save(sender=self.request.user)

        message.is_delivered = True
        message.save()
        
        mqtt_payload = {
            'type': 'new_message',
            'id': message.id,
            'sender_id': message.sender.id,
            'sender': message.sender.username,
            'content': message.content,
            'timestamp': str(message.timestamp)
        }
        
        publish_message(message.receiver.id, mqtt_payload)
        
        headers = self.get_success_headers(serializer.data)
        return Response({
            'data': serializer.data,
            'mqtt_service': {
                'broker': 'mqtt://broker.emqx.io',
                'topic': f'bishal_chat/user/{message.receiver.id}',
                'payload_format': 'JSON',
                'exact_payload_sent': mqtt_payload
            }
        }, status=201, headers=headers)

class MessageDeleteView(generics.DestroyAPIView):
    queryset = Message.objects.all()
    permission_classes = (IsAuthenticated,)

    def get_queryset(self):
        return self.queryset.filter(sender=self.request.user)
    
    def perform_destroy(self, instance):
        receiver_id = instance.receiver.id
        msg_id = instance.id
        super().perform_destroy(instance)
        
        # Notify receiver via MQTT that message was deleted
        publish_message(receiver_id, {
            'type': 'message_deleted',
            'message_id': msg_id
        })

class MarkMessageReadView(generics.UpdateAPIView):
    queryset = Message.objects.all()
    permission_classes = (IsAuthenticated,)
    serializer_class = MessageSerializer

    def patch(self, request, *args, **kwargs):
        message = self.get_object()
        if message.receiver == request.user:
            message.is_read = True
            message.save()
            
            # Notify sender via MQTT that message was read
            publish_message(message.sender.id, {
                'type': 'message_read',
                'message_id': message.id
            })
            return Response({'status': 'read'})
        return Response({'status': 'error'}, status=403)

class DebugStateView(APIView):
    permission_classes = (AllowAny,)

    def get(self, request):
        status = {
            'database': 'unknown',
            'tables': {},
            'debug_mode': False,
        }
        
        from django.conf import settings
        status['debug_mode'] = settings.DEBUG
        
        try:
            db_engine = settings.DATABASES['default']['ENGINE']
            status['database'] = f"Using {db_engine}"
            
            # Check for tables
            table_names = connection.introspection.table_names()
            status['tables'] = {
                'auth_user': 'auth_user' in table_names,
                'users_profile': 'users_profile' in table_names,
                'users_message': 'users_message' in table_names,
            }
            status['all_tables'] = table_names[:20] # Show first 20 for reference
            
        except Exception as e:
            status['error'] = str(e)
            
        return Response(status)
