package com.project.template;

import com.project.template.persistence.entity.UserEntity;
import com.project.template.persistence.repository.UserRepository;
import lombok.AllArgsConstructor;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;

import java.util.List;

import static com.project.template.persistence.enumeration.GenderEnum.FEMALE;
import static com.project.template.persistence.enumeration.GenderEnum.MALE;

/**
 * @author Ouweshs28
 */
//@Component
@AllArgsConstructor
public class DataLoader implements ApplicationRunner {

    private final UserRepository userRepository;

    @Override
    public void run(ApplicationArguments args) {

        UserEntity userOuwesh = new UserEntity(null, "ouweshs28", "ouwesh@email.com", "Ouwesh", "Seeroo", MALE);
        UserEntity userSam = new UserEntity(null, "sam", "sam@email.com", "Sam", "Johnstone", MALE);
        UserEntity userRick = new UserEntity(null, "rick", "rick@email.com", "Rick", "Allan", MALE);
        UserEntity userHanaa = new UserEntity(null, "hanaa", "hanaa@gmail.com", "Hanaa", "Azeria", FEMALE);
        UserEntity userSara = new UserEntity(null, "sara", "sara@email.com", "Sara", "Johnstone", FEMALE);

        userRepository.saveAll(List.of(userOuwesh, userSam, userRick, userHanaa, userSara));
    }
}
