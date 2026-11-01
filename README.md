# Franchessca's · Peluquería en El Campello

Web de la peluquería Franchessca's (Carrer de Joan Baptista Basset i Ramos, 20 · 03560 El Campello, Alicante · 629 88 32 47).

## Contenido

| Archivo | Qué es |
|---|---|
| `index.html` | La web pública: portada, el salón, servicios, equipo, ritual, galería, transformaciones, opiniones, reservas y contacto |
| `admin.html` | Panel privado de la agenda para gestionar las citas (requiere iniciar sesión) |
| `supabase-config.js` | URL del proyecto de Supabase y clave **publicable** |
| `supabase/schema.sql` | Tablas, seguridad (RLS) y funciones de la base de datos de reservas |
| `fotos/` | Carpeta para fotos propias del salón |

## Reservas

Las citas se guardan en Supabase como «pendientes». Desde `admin.html` se confirman, cambian o cancelan, y se avisa a la clienta por WhatsApp con un mensaje ya escrito.

Horario de reservas: lunes a viernes, de 08:00 a 14:00.

> ⚠️ En este repositorio solo puede ir la clave **publicable** de Supabase. Nunca subas la clave secreta (`sb_secret_…`).

## Verlo en local

```bash
python -m http.server 5500
```

Y abrir http://localhost:5500 (el panel en http://localhost:5500/admin.html).

## Tecnología

HTML, CSS y JavaScript sin dependencias de compilación. Animaciones con GSAP + ScrollTrigger y scroll suave con Lenis (cargados desde CDN). Fotos provisionales de Unsplash.
