import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

part 'covid_data.g.dart';

///Fetch async latest data from JSON repository, process them and add to Hive database
Future<bool> getLatestData() async {
  var countries = await Hive.openBox<Country>('countries');
  var reports = await Hive.openBox<Report>('reports');

  final response =
      await http.get('https://pomber.github.io/covid19/timeseries.json')
          .timeout(Duration(seconds: 10));

  if (response.statusCode == 200) {
    Map<String, dynamic> data = jsonDecode(response.body);
    for (String country in data.keys) {
      List<Report> reportsObs = List<Report>.from(data[country].map((item) => new Report.fromJson(item)));
      if (countries.containsKey(country)) {
        var dbCountry = countries.get(country);
        var newEntries = reportsObs.length - dbCountry.reports.length;
        if (newEntries > 0) {
          for (int i = dbCountry.reports.length; i < reportsObs.length; i++) {
            var dayReport = reportsObs.elementAt(i);
            reports.put(dayReport.date.toIso8601String() + country, dayReport);
            dbCountry.reports.add(dayReport);
          }
        } else {
          //we are all up to date
          return true;
        }
      } else {
        var countryObj = Country(country: country);
        countryObj.reports = HiveList(reports);
        for (int i = 0; i < reportsObs.length; i++) {
          var dayReport = reportsObs.elementAt(i);
          reports.put(dayReport.date.toIso8601String() + country, dayReport);
          countryObj.reports.add(dayReport);
        }
        countries.put(country, countryObj);
      }
    }
    return true;
  } else
    return false;
}

Future<List<Country>> getCountries() async {
  var countries = await Hive.openBox<Country>('countries');
  return countries.values.toList();
}

Future<List<Report>> getCountryReports(String country) async {
  var countries = await Hive.openBox<Country>('countries');
  var countryData = countries.get(country);
  return countryData.reports;
}

@HiveType(typeId: 0)
class Country extends HiveObject {
  @HiveField(0)
  String country;
  @HiveField(1)
  HiveList<Report> reports;

  Country({this.country, this.reports});
}

@HiveType(typeId: 1)
class Report extends HiveObject {
  @HiveField(0)
  DateTime date;
  @HiveField(1)
  int deaths;
  @HiveField(2)
  int recovered;
  @HiveField(3)
  int confirmed;

  Report({this.date, this.confirmed, this.deaths, this.recovered});

  factory Report.fromJson(Map<String, dynamic> json) {
    List<String> tempDate = json['date'].toString().split("-");
    return Report(
        date: new DateTime(int.parse(tempDate[0]), int.parse(tempDate[1]),
            int.parse(tempDate[2])),
        confirmed: json['confirmed'],
        deaths: json['deaths'],
        recovered: json['recovered']);
  }
}
