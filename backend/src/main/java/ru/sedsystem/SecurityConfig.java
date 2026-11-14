package ru.sedsystem;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.*;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.*;
import java.util.List;
@Configuration
class SecurityConfig {
 @Bean PasswordEncoder encoder(){return new BCryptPasswordEncoder();}
 @Bean UserDetailsService users(PasswordEncoder e,@Value("${app.demo-password}") String p){return new InMemoryUserDetailsManager(
 User.withUsername("initiator").password(e.encode(p)).roles("INITIATOR").build(),
 User.withUsername("buyer").password(e.encode(p)).roles("BUYER").build(),
 User.withUsername("contractor").password(e.encode(p)).roles("CONTRACTOR").build(),
 User.withUsername("manager").password(e.encode(p)).roles("MANAGER").build(),
 User.withUsername("supplier1").password(e.encode(p)).roles("SUPPLIER").build(),
 User.withUsername("supplier2").password(e.encode(p)).roles("SUPPLIER").build());}
 @Bean SecurityFilterChain security(HttpSecurity h) throws Exception {return h.cors(Customizer.withDefaults()).csrf(c->c.disable()).sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS)).authorizeHttpRequests(a->a.anyRequest().authenticated()).httpBasic(Customizer.withDefaults()).build();}
 @Bean CorsConfigurationSource corsConfigurationSource(@Value("${app.cors-origin}") String origin){CorsConfiguration c=new CorsConfiguration();c.setAllowedOrigins(List.of(origin));c.setAllowedMethods(List.of("GET","POST","PUT","OPTIONS"));c.setAllowedHeaders(List.of("Authorization","Content-Type"));var s=new UrlBasedCorsConfigurationSource();s.registerCorsConfiguration("/**",c);return s;}
}
