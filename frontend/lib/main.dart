import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const StudyPlannerApp());
}

class StudyPlannerApp extends StatelessWidget {
  const StudyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Study Planner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController subjectController =
      TextEditingController();

  final TextEditingController hoursController =
      TextEditingController();

  List<Map<String, String>> subjects = [];

  List<String> studyPlan = [];
  List<bool> completedTasks = [];

  String selectedDifficulty = "Medium";
  DateTime? selectedDate;

  void addSubject() {
    String subjectName =
        subjectController.text.trim();

    if (subjectName.isEmpty) return;

    bool alreadyExists = subjects.any(
      (subject) =>
          subject["name"]!.toLowerCase() ==
          subjectName.toLowerCase(),
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Subject already added",
          ),
        ),
      );
      return;
    }

    setState(() {
      subjects.add({
        "name": subjectName,
        "difficulty": selectedDifficulty,
      });
    });

    subjectController.clear();
  }

  Future<void> pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> generatePlan() async {
    if (subjects.isEmpty ||
        hoursController.text.isEmpty ||
        selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill all fields",
          ),
        ),
      );
      return;
    }

    int daysLeft =
        selectedDate!.difference(DateTime.now()).inDays;

    final requestBody = {
      "subjects": subjects,
      "hours_per_day":
          int.parse(hoursController.text),
      "days_left":
          daysLeft <= 0 ? 1 : daysLeft,
    };

    final response = await http.post(
      Uri.parse(
        "http://127.0.0.1:8000/generate-plan",
      ),
      headers: {
        "Content-Type":
            "application/json",
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      List<String> generatedPlan = [];

      for (var item in data["study_plan"]) {
        generatedPlan.add(
          "${item["subject"]} "
          "(${item["difficulty"]}) "
          "- ${item["hours"]} hrs/day",
        );
      }

      setState(() {
        studyPlan = generatedPlan;
        completedTasks =
            List.generate(
          generatedPlan.length,
          (_) => false,
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Study Plan Generated Successfully",
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Error ${response.statusCode}",
          ),
        ),
      );
    }
  }

  double getProgress() {
    if (completedTasks.isEmpty) return 0;

    int completed = completedTasks
        .where((task) => task)
        .length;

    return completed /
        completedTasks.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("AI Study Planner"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller:
                    subjectController,
                decoration:
                    const InputDecoration(
                  labelText:
                      "Enter Subject",
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                  height: 10),

              DropdownButtonFormField<
                  String>(
                value:
                    selectedDifficulty,
                decoration:
                    const InputDecoration(
                  labelText:
                      "Difficulty",
                  border:
                      OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Easy",
                    child:
                        Text("Easy"),
                  ),
                  DropdownMenuItem(
                    value: "Medium",
                    child:
                        Text("Medium"),
                  ),
                  DropdownMenuItem(
                    value: "Hard",
                    child:
                        Text("Hard"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedDifficulty =
                        value!;
                  });
                },
              ),

              const SizedBox(
                  height: 10),

              TextField(
                controller:
                    hoursController,
                keyboardType:
                    TextInputType
                        .number,
                decoration:
                    const InputDecoration(
                  labelText:
                      "Hours Per Day",
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                  height: 10),

              ElevatedButton(
                onPressed: pickDate,
                child: Text(
                  selectedDate == null
                      ? "Select Exam Date"
                      : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                ),
              ),

              const SizedBox(
                  height: 10),

              ElevatedButton(
                onPressed: addSubject,
                child: const Text(
                    "Add Subject"),
              ),

              const SizedBox(
                  height: 10),

              ElevatedButton(
                onPressed: generatePlan,
                child: const Text(
                    "Generate Study Plan"),
              ),

              const SizedBox(
                  height: 20),

              const Center(
                child: Text(
                  "Subjects",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(
                  height: 10),

              ListView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount:
                    subjects.length,
                itemBuilder:
                    (context, index) {
                  return Card(
                    child: ListTile(
                      leading:
                          const Icon(
                              Icons.book),
                      title: Text(
                        subjects[index]
                            ["name"]!,
                      ),
                      subtitle: Text(
                        "Difficulty: ${subjects[index]["difficulty"]}",
                      ),
                      trailing:
                          IconButton(
                        icon: const Icon(
                            Icons.delete),
                        onPressed: () {
                          setState(() {
                            subjects.removeAt(
                                index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(
                  height: 20),

              if (studyPlan.isNotEmpty)
                Column(
                  children: [
                    const Text(
                      "Progress",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                        height: 10),
                    LinearProgressIndicator(
                      value:
                          getProgress(),
                    ),
                    const SizedBox(
                        height: 10),
                    Text(
                      "${(getProgress() * 100).toStringAsFixed(0)}% Completed",
                    ),
                  ],
                ),

              const SizedBox(
                  height: 20),

              const Center(
                child: Text(
                  "Generated Study Plan",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(
                  height: 10),

              ListView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount:
                    studyPlan.length,
                itemBuilder:
                    (context, index) {
                  return Card(
                    child: CheckboxListTile(
                      value:
                          completedTasks
                                      .length >
                                  index
                              ? completedTasks[
                                  index]
                              : false,
                      title: Text(
                        studyPlan[index],
                      ),
                      onChanged:
                          (value) {
                        setState(() {
                          completedTasks[
                                  index] =
                              value!;
                        });
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}