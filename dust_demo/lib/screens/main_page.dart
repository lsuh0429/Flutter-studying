import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dustdemo/mapCons/constants.dart';

class MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: MapSample(),
    );
  }
}

class MapSample extends StatefulWidget {
  MapSample({this.email});

  final String email;

  @override
  _MapSampleState createState() => _MapSampleState();
}

class _MapSampleState extends State<MapSample> {
  Completer<GoogleMapController> _controller = Completer();
  MapType _googleMapType = MapType.normal;
  int _mapType = 0;
  Set<Marker> _markers = Set();
  GlobalKey<FormBuilderState> _fbKey = GlobalKey<FormBuilderState>();

  @override
  void initState() {
    super.initState();
    _markers.add(Marker(
        markerId: MarkerId('myInitialPosition'),
        position: LatLng(36.771476, 126.936932),
        infoWindow: InfoWindow(title: '경희학성아파트', snippet: '28.3 ㎍/m³')));
  }

  CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(36.771476, 126.936932),
    zoom: 14,
  );

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  void _changeMapType() {
    setState(() {
      _mapType++;
      _mapType = _mapType % 4;

      switch (_mapType) {
        case 0:
          _googleMapType = MapType.normal;
          break;
        case 1:
          _googleMapType = MapType.satellite;
          break;
        case 2:
          _googleMapType = MapType.terrain;
          break;
        case 3:
          _googleMapType = MapType.hybrid;
          break;
        default:
          _googleMapType = MapType.normal;
          break;
      }
    });
  }

  void _searchPlaces(
    String locationName,
    double latitude,
    double longitude,
  ) async {
    setState(() {
      _markers.clear();
    });

    final String url =
        '$baseUrl?key=$API_KEY&location=$latitude,$longitude&radius=1000&language=ko&keyword=$locationName';

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(latitude, longitude),
          ),
        );

        setState(() {
          final foundPlaces = data['results'];

          for (int i = 0; i < foundPlaces.length; i++) {
            _markers.add(
              Marker(
                markerId: MarkerId(foundPlaces[i]['id']),
                position: LatLng(
                  foundPlaces[i]['geometry']['location']['lat'],
                  foundPlaces[i]['geometry']['location']['lng'],
                ),
                infoWindow: InfoWindow(
                  title: foundPlaces[i]['name'],
                  snippet: foundPlaces[i]['vicinity'],
                ),
              ),
            );
          }
        });
      }
    } else {
      print('Fail to fetch place data');
    }
  }

  void _submit() {
    if (!_fbKey.currentState.validate()) {
      return;
    }
    _fbKey.currentState.save();
    final inputValues = _fbKey.currentState.value;
    final id = inputValues['placeId'];
    print(id);

    final foundPlace = places.firstWhere(
      (place) => place['id'] == id,
      orElse: () => null,
    );

    print(foundPlace['placeName']);
    _searchPlaces(foundPlace['placeName'], 36.769643, 126.931721);
    Navigator.of(context).pop();
  }

  void _findSCH() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15.0),
          topRight: Radius.circular(15.0),
        ),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: 40,
                    right: 20,
                    left: 20,
                    bottom: 20,
                  ),
                  child: FormBuilder(
                    key: _fbKey,
                    child: Column(
                      children: <Widget>[
                        FormBuilderDropdown(
                          attribute: 'placeId',
                          hint: Text('어떤 장소를 원하세요?'),
                          decoration: InputDecoration(
                            filled: true,
                            labelText: '장소',
                            border: OutlineInputBorder(),
                          ),
                          validators: [
                            FormBuilderValidators.required(
                              errorText: '장소 선택은 필수입니다!',
                            )
                          ],
                          items: places.map<DropdownMenuItem<String>>(
                                (place) {
                              return DropdownMenuItem<String>(
                                value: place['id'],
                                child: Text(place['placeName']),
                              );
                            },
                          ).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                MaterialButton(
                  child: Text('Submit'),
                  onPressed: _submit,
                  color: Colors.indigo,
                  textColor: Colors.white,
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text("미세먼지를 확인하세요!"),
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 30.0,
            ),
            tooltip: "logout",
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: Stack(children: <Widget>[
        GoogleMap(
          mapType: _googleMapType,
          initialCameraPosition: _initialCameraPosition,
          onMapCreated: _onMapCreated,
          myLocationEnabled: true,
          markers: _markers,
        ),
        Container(
          margin: EdgeInsets.only(top: 30, right: 10),
          alignment: Alignment.topRight,
          child: Column(
            children: <Widget>[
              FloatingActionButton.extended(
                  label: Text('지도 모양 바꾸기'),
                  icon: Icon(Icons.map),
                  elevation: 8,
                  backgroundColor: Colors.blue[400],
                  onPressed: _changeMapType),
              SizedBox(height: 10),
              FloatingActionButton.extended(
                label: Text('주변 시설 보기'),
                icon: Icon(Icons.zoom_in),
                elevation: 8,
                backgroundColor: Colors.teal[400],
                onPressed: _findSCH,
              )
            ],
          ),
        )
      ]),
    );
  }
}
