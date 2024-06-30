
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_ds/Components/VideoPlayerComp.dart';

import 'Components/Loading.dart';

void main()  {
    WidgetsFlutterBinding.ensureInitialized();
    runApp( Shortcuts(
      shortcuts: <LogicalKeySet,Intent>{
        LogicalKeySet(LogicalKeyboardKey.select):const ActivateIntent(),
      },
      child: const MaterialApp(
        home: Loading(),
        debugShowCheckedModeBanner: false,
        // home: VideoPlayerSync(),
      ),
    ));
}
