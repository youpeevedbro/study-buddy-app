import 'package:flutter/material.dart';
import 'package:study_buddy/components/grad_button.dart';
import 'login.dart';
import 'createaccount.dart';

class HomePage extends StatelessWidget{
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: IntrinsicWidth(
          child: Column(
            children: [
              SizedBox(height: 140),
              SizedBox(
                height: 225,
                child: Image.asset(
                  'assets/images/elbee.png',
                  fit: BoxFit.contain
                )
              ),
              SizedBox(height: 80),
              Text(
                "Study Buddy",
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 80),
              GradientButton(
                width: double.infinity,
                height: 50,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                borderRadius: BorderRadius.circular(15),
                child: Text(
                  'Login',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Colors.white)
                ),
              ),
              SizedBox(height: 15),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateAccountPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  minimumSize: Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  )
                ),
                child: Text(
                  'Register',
                  style: Theme.of(context).textTheme.titleLarge
                ),
              ),
            ],
          ),
        )
      ) ,
    );
  }
}


    
