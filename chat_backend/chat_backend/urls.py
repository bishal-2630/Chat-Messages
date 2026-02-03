
from django.contrib import admin
from django.urls import path, re_path
from django.urls import include
from django.views.generic import TemplateView
from django.conf import settings
from django.conf.urls.static import static

from rest_framework.schemas import get_schema_view

urlpatterns = [
    path('api/', include('users.urls')),
    # Use built-in DRF schema - lightweight and Vercel-compatible
    path('api/schema/', get_schema_view(
        title="Chat App API",
        description="API documentation for the Chat App",
        version="1.0.0",
        public=True,
    ), name='openapi-schema'),
]

# Serve Flutter web app for all other routes (SPA routing)
urlpatterns += [
    re_path(r'^.*$', TemplateView.as_view(template_name='index.html')),
]

# Serve static files in development
if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
