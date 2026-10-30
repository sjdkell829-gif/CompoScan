import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'db/database_helper.dart';

class GifAnimado extends StatefulWidget {
  final String asset;
  final double? height;
  const GifAnimado(this.asset, {super.key, this.height});
  @override
  State<GifAnimado> createState() => _GifAnimadoState();
}

class _GifAnimadoState extends State<GifAnimado> {
  ui.Codec? _codec;
  ui.FrameInfo? _frame;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await rootBundle.load(widget.asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    _codec = codec;
    _next();
  }

  Future<void> _next() async {
    if (_codec == null) return;
    final f = await _codec!.getNextFrame();
    if (!mounted) return;
    setState(() => _frame = f);
    _timer = Timer(f.duration, _next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codec?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frame == null) return SizedBox(height: widget.height);
    return RawImage(image: _frame!.image, height: widget.height);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isCupertino = false;
  bool _loggedIn = false;
  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!_loggedIn) {
      home = LoginPage(
        isIOS: _isCupertino,
        onToggle: (v) => setState(() => _isCupertino = v),
        onLoginSuccess: () => setState(() => _loggedIn = true),
      );
    } else {
      home = MiPagina(
        isIOS: _isCupertino,
        onToggle: (v) => setState(() => _isCupertino = v),
      );
    }
    if (_isCupertino)
      return CupertinoApp(debugShowCheckedModeBanner: false, home: home);
    return MaterialApp(debugShowCheckedModeBanner: false, home: home);
  }
}

class LoginPage extends StatefulWidget {
  final bool isIOS;
  final Function(bool) onToggle;
  final VoidCallback onLoginSuccess;
  const LoginPage({
    super.key,
    required this.isIOS,
    required this.onToggle,
    required this.onLoginSuccess,
  });
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  void _alertaIOS(String titulo, String msg, {VoidCallback? onOk}) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Ok'),
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _onEntrar() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (user.isEmpty || pass.isEmpty) {
      _alertaIOS('Campos vacíos', 'Escribe usuario y contraseña');
      return;
    }
    setState(() => _loading = true);
    final ok = await DatabaseHelper.instance.checkLogin(user, pass);
    setState(() => _loading = false);
    if (ok) {
      _alertaIOS('¡Éxito!', 'Se pudo entrar', onOk: widget.onLoginSuccess);
    } else {
      _alertaIOS('Error', 'Usuario o contraseña incorrectos');
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isIOS
        ? CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Login SQLite'),
            ),
            child: SafeArea(child: _buildContenido()),
          )
        : Scaffold(
            appBar: AppBar(title: const Text('Login SQLite')),
            body: _buildContenido(),
          );
  }

  Widget _buildContenido() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.isIOS ? 'Modo iOS' : 'Modo Google'),
              CupertinoSwitch(value: widget.isIOS, onChanged: widget.onToggle),
            ],
          ),
          const SizedBox(height: 20),
          Image.asset(
            'asset/images/papu.png',
            height: 120,
            width: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 10),
          const Text(
            'Login SQLite',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 25),

          // USUARIO A LA IZQUIERDA (sin mostrar papu)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 100,
                child: Text(
                  'Usuario:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // CONTRASEÑA A LA IZQUIERDA (sin mostrar 1234)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 100,
                child: Text(
                  'Contraseña:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : ElevatedButton(
                    onPressed: _onEntrar,
                    child: const Text('Entrar'),
                  ),
          ),
        ],
      ),
    );
  }
}

class MiPagina extends StatefulWidget {
  final bool isIOS;
  final Function(bool) onToggle;
  const MiPagina({super.key, required this.isIOS, required this.onToggle});
  @override
  State<MiPagina> createState() => _MiPaginaState();
}

class _MiPaginaState extends State<MiPagina>
    with SingleTickerProviderStateMixin {
  final _control = TextEditingController();
  String _mostrar = '';
  late AnimationController _giro;
  @override
  void initState() {
    super.initState();
    _giro = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _giro.dispose();
    _control.dispose();
    super.dispose();
  }

  bool _esValido(String t) => RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(t);
  void _alerta(String titulo, String msg) {
    if (widget.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text(titulo),
          content: Text(msg),
          actions: [
            CupertinoDialogAction(
              child: const Text('Ok'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(titulo),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    }
  }

  void _onPrueba() {
    final texto = _control.text.trim();
    if (texto.isEmpty) {
      _alerta('Vacío', 'Escribe algo');
      return;
    }
    if (!_esValido(texto)) {
      _alerta('No permitido', 'Solo letras');
      return;
    }
    setState(() => _mostrar = texto);
    _alerta('OK', texto);
  }

  @override
  Widget build(BuildContext context) {
    final stackGif = Stack(
      alignment: Alignment.center,
      children: [
        const GifAnimado('asset/images/sans.gif', height: 180),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'TEXTO ENFRENTE DEL GIF',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
    final contenido = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.isIOS ? 'Modo iOS' : 'Modo Google'),
              CupertinoSwitch(value: widget.isIOS, onChanged: widget.onToggle),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Hola',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          stackGif,
          const SizedBox(height: 20),
          widget.isIOS
              ? CupertinoTextField(
                  controller: _control,
                  placeholder: 'Solo letras',
                )
              : TextField(
                  controller: _control,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Solo letras',
                  ),
                ),
          const SizedBox(height: 10),
          widget.isIOS
              ? CupertinoButton.filled(
                  onPressed: _onPrueba,
                  child: const Text('prueba'),
                )
              : ElevatedButton(
                  onPressed: _onPrueba,
                  child: const Text('prueba'),
                ),
          const SizedBox(height: 10),
          Text(
            _mostrar,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          RotationTransition(
            turns: _giro,
            child: const Text(
              'Cargando... cambiando constantemente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FnafPage()),
            ),
            child: const Text('5 noches con alfredo'),
          ),
        ],
      ),
    );
    return widget.isIOS
        ? CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(middle: Text('Tarea')),
            child: SafeArea(child: contenido),
          )
        : Scaffold(
            appBar: AppBar(title: const Text('Google simple')),
            body: contenido,
          );
  }
}

class FnafPage extends StatelessWidget {
  const FnafPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('5 noches con alfredo'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'ITS BEEN SO LONG - FNAF',
              style: TextStyle(
                color: Colors.purpleAccent,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                const GifAnimado('asset/images/sans.gif', height: 120),
                Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(4),
                  child: const Text(
                    'JUMPSCARE',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purpleAccent),
              ),
              child: const Text(
                "It's been so long,\nSince I last have seen my son\nLost to this monster\nTo the man behind the slaughter",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, height: 1.6),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huir de Alfredo'),
            ),
          ],
        ),
      ),
    );
  }
}
