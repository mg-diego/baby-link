import 'package:flutter/material.dart';
import '../../features/profile/screens/profile_screen.dart'; // Ajusta la ruta según tu proyecto

class CustomTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// El contenido dinámico que irá en el centro de la barra
  final Widget centerContent;
  
  /// Opcional: Si en alguna pantalla necesitas botones extra a la derecha
  final List<Widget>? actions;

  const CustomTopBar({
    super.key,
    required this.centerContent,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Botón del perfil fijo a la izquierda
      leading: IconButton(
        icon: const Icon(Icons.person_outline),
        tooltip: 'Mi Perfil',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        },
      ),
      // Contenido custom en el centro
      title: centerContent,
      centerTitle: true,
      // Botones extra a la derecha (opcional)
      actions: actions,
      
      // Puedes forzar estilos aquí si quieres que la barra sea idéntica siempre
      // backgroundColor: Theme.of(context).colorScheme.surface,
      // elevation: 0,
    );
  }

  // Esto es OBLIGATORIO para que Flutter te deje usarlo en Scaffold(appBar: ...)
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}