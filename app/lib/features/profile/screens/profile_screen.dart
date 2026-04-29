import 'package:app/features/auth/services/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../babies/providers/baby_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final babyAsync = ref.watch(babyProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Sección de Usuario
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                user?.email?.substring(0, 2).toUpperCase() ?? 'U',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.email ?? 'Usuario',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 40),

            // Sección de Información del Bebé
            _buildSectionTitle(context, 'Mi Bebé'),
            babyAsync.when(
              data: (baby) => baby != null
                  ? _buildInfoCard(
                      context,
                      title: baby['name'] ?? 'Bebé',
                      subtitle: 'Fecha de nacimiento: ${baby['dob']}',
                      icon: Icons.child_care,
                    )
                  : _buildInfoCard(
                      context,
                      title: 'Sin bebé vinculado',
                      subtitle: 'Configura los datos de tu bebé',
                      icon: Icons.add_circle_outline,
                      onTap: () {
                        // Navegar a BabyFormScreen si fuera necesario
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error al cargar datos: $err'),
            ),

            const SizedBox(height: 30),
            _buildSectionTitle(context, 'Cuenta'),
            
            // Botón de Cerrar Sesión
            _buildInfoCard(
              context,
              title: 'Cerrar Sesión',
              subtitle: 'Salir de la cuenta actual',
              icon: Icons.logout,
              iconColor: Colors.redAccent,
              onTap: () async {
                final confirm = await _showLogoutDialog(context);
                if (confirm == true) {
                  await authService.signOut();
                  // El AuthWrapper en main.dart detectará el cambio y mostrará el Login
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0, left: 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: onTap != null ? const Icon(Icons.chevron_right, size: 20) : null,
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, salir', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}