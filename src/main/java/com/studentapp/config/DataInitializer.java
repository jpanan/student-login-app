package com.studentapp.config;

import com.studentapp.model.Student;
import com.studentapp.service.StudentService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class DataInitializer implements CommandLineRunner {

    @Autowired
    private StudentService studentService;

    @Override
    public void run(String... args) throws Exception {
        // Create a demo student if it doesn't exist
        if (!studentService.existsByUsername("student1")) {
            Student demoStudent = new Student();
            demoStudent.setUsername("student1");
            demoStudent.setPassword("password123");
            demoStudent.setFirstName("John");
            demoStudent.setLastName("Doe");
            demoStudent.setEmail("john.doe@example.com");
            demoStudent.setStudentId("STU001");
            demoStudent.setCourse("Computer Science");
            demoStudent.setYear(3);

            studentService.registerStudent(demoStudent);
            System.out.println("Demo student created: username=student1, password=password123");
        }
    }
}
