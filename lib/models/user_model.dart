class UserModel {
  final String token;
  final String email;
  final String firstName;
  final String surname;

  UserModel({
    required this.token,
    required this.email,
    required this.firstName,
    required this.surname,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      token:     json['token']     as String,
      email:     json['email']     as String,
      firstName: json['firstName'] as String,
      surname:   json['surname']   as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'token':     token,
    'email':     email,
    'firstName': firstName,
    'surname':   surname,
  };
}