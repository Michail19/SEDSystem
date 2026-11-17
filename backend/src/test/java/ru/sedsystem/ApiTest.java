package ru.sedsystem;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.web.server.ResponseStatusException;

class ApiTest {
 private final JdbcTemplate db=mock(JdbcTemplate.class);
 private final Api api=new Api(db);
 private TestingAuthenticationToken user(String name,String role){return new TestingAuthenticationToken(name,"ignored","ROLE_"+role);}
 @Test void supplierCannotCreateRequest(){var e=assertThrows(ResponseStatusException.class,()->api.createRequest(user("supplier1","SUPPLIER"),Map.of()));assertEquals(403,e.getStatusCode().value());verifyNoInteractions(db);}
 @Test void cannotApproveUnsubmittedRequest(){when(db.queryForList(anyString(),eq(1L))).thenReturn(List.of(Map.of("status","DRAFT","initiator","initiator")));var e=assertThrows(ResponseStatusException.class,()->api.requestAction(user("manager","MANAGER"),1,"approve",Map.of()));assertEquals(409,e.getStatusCode().value());verify(db,never()).update(anyString(),any(),any());}
 @Test void cannotChooseUnacceptedOffer(){when(db.queryForList(contains("procedures"),eq(1L))).thenReturn(List.of(Map.of("status","OPEN")));when(db.queryForObject(anyString(),eq(Integer.class),eq(1L))).thenReturn(0);when(db.queryForList(contains("offers"),eq(2L))).thenReturn(List.of(Map.of("status","REJECTED","procedure_id",1L)));var e=assertThrows(ResponseStatusException.class,()->api.result(user("buyer","BUYER"),1,Map.of("outcome","WINNER","offerId",2)));assertEquals(400,e.getStatusCode().value());}
}
