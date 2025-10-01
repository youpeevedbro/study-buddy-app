import 'package:flutter/material.dart';
import 'package:study_buddy/components/grad_button.dart';

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
                  'assets/elbee.png', 
                  fit: BoxFit.contain
                )
              ),
              SizedBox(height: 80),
              Text(
                "Studdy Buddy", 
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 80),
              GradientButton(
                width: double.infinity,
                height: 50,
                onPressed: () {},
                borderRadius: BorderRadius.circular(15),
                child: Text(
                  'Login',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Colors.white)
                ),
              ),
              SizedBox(height: 15),
              OutlinedButton( 
                onPressed: (){},
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


    
