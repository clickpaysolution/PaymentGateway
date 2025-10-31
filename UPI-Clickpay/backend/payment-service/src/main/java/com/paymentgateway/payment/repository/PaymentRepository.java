package com.paymentgateway.payment.repository;

import com.paymentgateway.payment.entity.Payment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
    Optional<Payment> findByTransactionId(String transactionId);
    
    List<Payment> findByMerchantIdOrderByCreatedAtDesc(Long merchantId);
    
    @Query("SELECT p FROM Payment p WHERE p.merchantId = :merchantId AND p.createdAt BETWEEN :startDate AND :endDate ORDER BY p.createdAt DESC")
    List<Payment> findByMerchantIdAndDateRange(@Param("merchantId") Long merchantId, 
                                             @Param("startDate") LocalDateTime startDate, 
                                             @Param("endDate") LocalDateTime endDate);
    
    @Query("SELECT COUNT(p) FROM Payment p WHERE p.merchantId = :merchantId AND p.status = :status")
    Long countByMerchantIdAndStatus(@Param("merchantId") Long merchantId, @Param("status") Payment.PaymentStatus status);
}