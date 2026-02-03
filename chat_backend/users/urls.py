from django.urls import path
from .views import (
    RegisterView, UserListView, MessageListCreateView, 
    CustomAuthToken, MessageDeleteView, MarkMessageReadView, TestMQTTView
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', CustomAuthToken.as_view(), name='login'),
    path('users/', UserListView.as_view(), name='user-list'),
    path('messages/', MessageListCreateView.as_view(), name='message-list-create'),
    path('messages/<int:pk>/delete/', MessageDeleteView.as_view(), name='message-delete'),
    path('messages/<int:pk>/read/', MarkMessageReadView.as_view(), name='message-mark-read'),
    path('test-mqtt/', TestMQTTView.as_view(), name='test-mqtt'),
]