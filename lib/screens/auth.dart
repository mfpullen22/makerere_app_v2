import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:firebase_auth/firebase_auth.dart";

final _firebase = FirebaseAuth.instance;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  var _isLogin = true;
  final _form = GlobalKey<FormState>();
  var _enteredEmail = "";
  var _enteredPassword = "";
  var _idToken = "";
  var _isAuthenticating = false;
  bool _isStudentOrFaculty = false;
  String _enteredFirstname = '';
  String _enteredLastname = '';
  String _selectedClass = '';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  /*   void _submit() async {
    final isValid = _form.currentState!.validate();

    if (!isValid) {
      return;
    }

    _form.currentState!.save();

    try {
      setState(() {
        _isAuthenticating = true;
      });
      if (_isLogin) {
        // ignore: unused_local_variable
        final userCredentials = await _firebase.signInWithEmailAndPassword(
          email: _enteredEmail,
          password: _enteredPassword,
        );
      } else {
        final querySnapshot = await FirebaseFirestore.instance
            .collection("users")
            .where("id_token", isEqualTo: _idToken)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userDoc = querySnapshot.docs.first;

          await _firebase.createUserWithEmailAndPassword(
            email: _enteredEmail,
            password: _enteredPassword,
          );

          await userDoc.reference.update({
            "email": _enteredEmail,
            "id_token": FieldValue.delete(),
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Invalid ID token.")));
          }
        }
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
          });
        }

        return;
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        if (error.code == "email-already-in-use") {
          // ...
        }
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? "Authentication failed.")),
        );
      }
      setState(() {
        _isAuthenticating = false;
      });
    }
  } */
  void _clearFormFields() {
    _form.currentState?.reset(); // Clear form validation state
    _emailController.clear();
    _passwordController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    _inviteCodeController.clear();
    _selectedClass = '';
  }

  void _submit() async {
    final isValid = _form.currentState!.validate();
    if (!isValid) return;
    _form.currentState!.save();

    try {
      setState(() => _isAuthenticating = true);

      if (_isLogin) {
        await _firebase.signInWithEmailAndPassword(
          email: _enteredEmail,
          password: _enteredPassword,
        );
      } else {
        if (!_isLogin) {
          String role = 'guest'; // default

          if (_isStudentOrFaculty) {
            final inviteCode = _idToken.trim().toLowerCase();

            final codeSnapshot = await FirebaseFirestore.instance
                .collection('invite_codes')
                .where('code', isEqualTo: inviteCode)
                .limit(1)
                .get();

            if (codeSnapshot.docs.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid invite code.")),
                );
              }
              setState(() => _isAuthenticating = false);
              return;
            }

            final codeDoc = codeSnapshot.docs.first;
            role = codeDoc['role'];

            // (Optional) Check expiration or usage limit
            final Timestamp? expires = codeDoc.data()['expires'];
            final int? usesRemaining = codeDoc.data()['usesRemaining'];

            if (expires != null && expires.toDate().isBefore(DateTime.now())) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Your error message here")),
                );
              }
              setState(() => _isAuthenticating = false);
              return;
            }
            if (usesRemaining != null && usesRemaining <= 0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Your error message here")),
                );
              }
              setState(() => _isAuthenticating = false);
              return;
            }

            if (usesRemaining != null) {
              await codeDoc.reference.update({
                "usesRemaining": FieldValue.increment(-1),
              });
            }
          }

          final userCredentials = await _firebase
              .createUserWithEmailAndPassword(
                email: _enteredEmail,
                password: _enteredPassword,
              );

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredentials.user!.uid)
              .set({
                "firstname": _enteredFirstname,
                "lastname": _enteredLastname,
                "email": _enteredEmail,
                "role": role,
                "class": role == "student" ? _selectedClass : null,
                "attendance": false,
                "reviews": [],
                "schedule": {},
                "createdAt": Timestamp.now(),
              });
        }
      }

      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? "Authentication failed.")),
        );
      }
      setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(
                  top: 30,
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                width: 200,
                child: Image.asset("assets/images/mak_logo.png"),
              ),
              Card(
                margin: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isLogin) ...[
                            TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: "First Name",
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Please enter your first name.";
                                }
                                return null;
                              },
                              onSaved: (value) =>
                                  _enteredFirstname = value!.trim(),
                            ),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: "Last Name",
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Please enter your last name.";
                                }
                                return null;
                              },
                              onSaved: (value) =>
                                  _enteredLastname = value!.trim(),
                            ),
                          ],
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: "Email Address",
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty ||
                                  !value.contains("@")) {
                                return "Please enter a valid email address.";
                              }
                              return null;
                            },
                            onSaved: (value) => _enteredEmail = value!,
                          ),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: "Password",
                            ),
                            obscureText: true,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            validator: (value) {
                              if (value == null || value.trim().length < 6) {
                                return "Password must be at least 6 characters.";
                              }
                              return null;
                            },
                            onSaved: (value) => _enteredPassword = value!,
                          ),
                          if (!_isLogin) ...[
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                "I am a student or faculty member",
                              ),
                              value: _isStudentOrFaculty,
                              onChanged: (value) {
                                setState(() {
                                  _isStudentOrFaculty = value ?? false;
                                  _selectedClass = '';
                                });
                              },
                            ),
                            if (_isStudentOrFaculty) ...[
                              TextFormField(
                                controller: _inviteCodeController,
                                decoration: const InputDecoration(
                                  labelText: "Invite Code",
                                ),
                                validator: (value) {
                                  if (_isStudentOrFaculty &&
                                      (value == null || value.trim().isEmpty)) {
                                    return "Please enter your invite code.";
                                  }
                                  return null;
                                },
                                onSaved: (value) =>
                                    _idToken = value?.trim() ?? '',
                              ),
                              DropdownButtonFormField<String>(
                                value: _selectedClass.isNotEmpty
                                    ? _selectedClass
                                    : null,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'undergrad',
                                    child: Text('Undergraduate'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'mmed1',
                                    child: Text('MMed1'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'mmed2',
                                    child: Text('MMed2'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'mmed3',
                                    child: Text('MMed3'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'faculty',
                                    child: Text('Faculty'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedClass = value ?? '';
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: "Class",
                                ),
                                validator: (value) {
                                  if (_isStudentOrFaculty &&
                                      (value == null || value.isEmpty)) {
                                    return "Please select your class.";
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                          const SizedBox(height: 12),
                          if (_isAuthenticating)
                            const CircularProgressIndicator()
                          else
                            ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                              ),
                              child: Text(_isLogin ? "Login" : "Sign Up"),
                            ),
                          if (!_isAuthenticating)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _isStudentOrFaculty = false;
                                  _idToken = '';
                                  _clearFormFields();
                                });
                              },
                              child: Text(
                                _isLogin
                                    ? "Create new account"
                                    : "I already have an account",
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
