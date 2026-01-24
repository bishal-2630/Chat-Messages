from django.urls import path
from .views import RegisterView, UserListView, MessageListCreateView, CustomAuthToken

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', CustomAuthToken.as_view(), name='login'), # Use Custom View
    path('users/', UserListView.as_view(), name='user-list'),
    path('messages/', MessageListCreateView.as_view(), name='message-list-create'),
]