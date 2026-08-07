package com.project.template.persistence.repository;

import com.project.template.persistence.entity.UserEntity;
import com.project.template.persistence.enumeration.GenderEnum;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Shared JPA specifications for {@link UserEntity} queries.
 */
public final class UserSpecifications {

    private UserSpecifications() {
    }

    public static Specification<UserEntity> filter(String criteria, GenderEnum gender) {
        return (root, query, builder) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (criteria != null && !criteria.isBlank()) {
                String pattern = "%" + criteria.toLowerCase(Locale.ROOT) + "%";
                predicates.add(builder.or(
                        builder.like(builder.lower(root.get("firstName")), pattern),
                        builder.like(builder.lower(root.get("lastName")), pattern),
                        builder.like(builder.lower(root.get("username")), pattern),
                        builder.like(builder.lower(root.get("email")), pattern)
                ));
            }

            if (gender != null) {
                predicates.add(builder.equal(root.get("gender"), gender));
            }

            return predicates.isEmpty()
                    ? builder.conjunction()
                    : builder.and(predicates.toArray(Predicate[]::new));
        };
    }
}
