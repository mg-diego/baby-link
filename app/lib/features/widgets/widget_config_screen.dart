import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

class WidgetConfigScreen extends StatefulWidget {
  final int widgetId;
  const WidgetConfigScreen({super.key, required this.widgetId});

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  static const platform = MethodChannel('widget_config');

  // Estado del formulario
  String _selectedCategory = 'bottle';
  
  // Variables Biberón
  String _bottleType = 'Fórmula';
  final _mlController = TextEditingController(text: '120');

  // Variables Pañal
  String _diaperCondition = 'Sucio';
  
  // Variables Lactancia
  String _nursingSide = 'Ambos';

  final Map<String, String> _categories = {
    'bottle': 'Biberón',
    'nursing': 'Lactancia',
    'solids': 'Sólidos',
    'diaper': 'Pañal',
    'nap': 'Siesta',
    'woke_up': 'Se despertó',
    'bed_time': 'Hora de dormir',
    'night_waking': 'Despertar Nocturno'
  };

  Future<void> _saveConfig() async {
    String title = '';
    Map<String, String> queryParams = {};

    switch (_selectedCategory) {
      case 'bottle':
        title = '🍼';
        queryParams['category'] = 'feed';
        queryParams['type'] = 'bottle';
        queryParams['milk_type'] = _bottleType;
        queryParams['amount_ml'] = _mlController.text;
        break;
      case 'nursing':
        title = '🤱';
        queryParams['category'] = 'feed';
        queryParams['type'] = 'nursing';
        queryParams['side'] = _nursingSide;
        break;
      case 'solids':
        title = '🍴';
        queryParams['category'] = 'feed';
        queryParams['type'] = 'solids';
        break;
      case 'diaper':
        title = '💩';
        queryParams['category'] = 'diaper';
        
        title = '💦';
        String backendCond = 'wet';
        if (_diaperCondition == 'Sucio') {
          title = '💩';
          backendCond = 'dirty';
        }          
        if (_diaperCondition == 'Variado') {
          title = '🩲';
          backendCond = 'mixed';
        }
        if (_diaperCondition == 'Seco'){
          title = '🩲';
          backendCond = 'clean';
        }
        
        queryParams['condition'] = backendCond;
        queryParams['ui_condition'] = _diaperCondition;
        break;
      default:
        title = _categories[_selectedCategory] ?? 'Acción';
        queryParams['category'] = _selectedCategory;
    }

    queryParams['widgetId'] = widget.widgetId.toString();

    final uri = Uri(
      scheme: 'babycare',
      host: 'action',
      queryParameters: queryParams,
    );

    await HomeWidget.saveWidgetData<String>('widget_${widget.widgetId}_title', title);
    await HomeWidget.saveWidgetData<String>('widget_${widget.widgetId}_uri', uri.toString());
    
    await HomeWidget.updateWidget(name: 'QuickActionsWidgetProvider');
    await platform.invokeMethod('finishWidgetConfig');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar Acción Rápida')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Selector Principal de Categoría
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Tipo de Evento'),
              items: _categories.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            
            const SizedBox(height: 30),

            // 2. Campos Dinámicos
            Expanded(
              child: SingleChildScrollView(
                child: _buildDynamicFields(),
              ),
            ),

            // 3. Botón Guardar
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saveConfig,
              child: const Text('Crear Botón en Escritorio', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // Renderiza los campos según la categoría seleccionada
  Widget _buildDynamicFields() {
    switch (_selectedCategory) {
      case 'bottle':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de Leche', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Fórmula', label: Text('Fórmula')),
                ButtonSegment(value: 'Materna', label: Text('Materna')),
                ButtonSegment(value: 'Leche', label: Text('Leche')),
              ],
              selected: {_bottleType},
              onSelectionChanged: (set) => setState(() => _bottleType = set.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _mlController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                suffixText: 'ml',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case 'diaper':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estado del Pañal', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Mojado', label: Text('Mojado')),
                ButtonSegment(value: 'Sucio', label: Text('Sucio')),
                ButtonSegment(value: 'Variado', label: Text('Variado')),
                ButtonSegment(value: 'Seco', label: Text('Seco')),
              ],
              selected: {_diaperCondition},
              onSelectionChanged: (set) => setState(() => _diaperCondition = set.first),
            ),
          ],
        );

      case 'nursing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pecho', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Izquierdo', label: Text('Izq')),
                ButtonSegment(value: 'Ambos', label: Text('Ambos')),
                ButtonSegment(value: 'Derecho', label: Text('Der')),
              ],
              selected: {_nursingSide},
              onSelectionChanged: (set) => setState(() => _nursingSide = set.first),
            ),
          ],
        );

      default:
        return const Center(
          child: Text('Esta acción se registrará instantáneamente sin opciones adicionales.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
        );
    }
  }
}