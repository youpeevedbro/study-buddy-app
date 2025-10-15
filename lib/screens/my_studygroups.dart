import 'package:flutter/material.dart';
import 'package:study_buddy/components/grad_button.dart';

//TEMPORARY: FOR DUMMY DATA
class StudyGroup{
  final String groupName;

  const StudyGroup({
    required this.groupName
  });
}



class MyStudyGroupsPage extends StatefulWidget{
  const MyStudyGroupsPage({super.key});

  @override
  State<MyStudyGroupsPage> createState() => _MyStudyGroupsPageState();
}

class _MyStudyGroupsPageState extends State<MyStudyGroupsPage> {
  //DUMMY DATA
  List <StudyGroup> groups = List.generate(10, (int index) => StudyGroup(groupName: 'StudyGroup$index'));
   

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Transform.translate(
            offset: const Offset(3.0, 0),
            child: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context), // back to Dashboard
        ),
        toolbarHeight: 100,
        title: const Text("Study Buddy"),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 40,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "My Study Groups",
                style: TextStyle(
                    fontSize: 26.0,
                    fontWeight: FontWeight.w900,
                )
              ),
              const Divider(
                thickness: 1.5,
                color: Colors.black,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GradientButton(
                    onPressed: () {}, 
                    borderRadius: BorderRadius.circular(12),
                    child: const Text(
                      "Add",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18
                        ),
                    )
                  ),
                  GradientButton(
                    onPressed: () {}, 
                    borderRadius: BorderRadius.circular(12),
                    child: const Text(
                      "Remove",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18
                        )
                    )
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                height: 480,
                child: ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.surfaceContainerLow
                          ),
                          backgroundColor: theme.colorScheme.surfaceContainerLow,
                        ),
                        onPressed: () {},
                        child: Text(
                          groups[index].groupName,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold
                          )
                        ),
                      )
                    );
                  }
                ),
              )
            ],
          )
        )
      )
    );
  }
}

