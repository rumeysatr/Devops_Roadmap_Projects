db = db.getSiblingDB("school");

  db.students.deleteMany({});

  db.students.insertMany([
    { name: "Ayşe Yılmaz",    department: "CSE",  gpa: 3.4 },
    { name: "Mehmet Demir",   department: "EEE",  gpa: 2.9 },
    { name: "Zeynep Kaya",    department: "CSE",  gpa: 3.8 },
    { name: "Can Öztürk",     department: "ME",   gpa: 2.6 },
    { name: "Elif Şahin",     department: "CSE",  gpa: 3.1 },
    { name: "Burak Aydın",    department: "IE",   gpa: 3.0 },
    { name: "Deniz Koç",      department: "EEE",  gpa: 2.8 },
    { name: "Merve Arslan",   department: "CSE",  gpa: 3.6 },
    { name: "Emre Çelik",     department: "ME",   gpa: 2.7 },
    { name: "Selin Yıldız",   department: "IE",   gpa: 3.3 },
  ]);

  print("Seed tamam. Öğrenci sayısı: " + db.students.countDocuments({}));

