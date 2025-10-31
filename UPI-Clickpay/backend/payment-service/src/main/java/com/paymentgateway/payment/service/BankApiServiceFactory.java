package com.paymentgateway.payment.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;

@Component
public class BankApiServiceFactory {

    private final BankApiService hdfcBankApiService;
    private final BankApiService iciciBankApiService;
    private final BankApiService kotakBankApiService;
    private final BankApiService axisBankApiService;

    @Autowired
    public BankApiServiceFactory(
            @Qualifier("hdfcBankApiService") BankApiService hdfcBankApiService,
            @Qualifier("iciciBankApiService") BankApiService iciciBankApiService,
            @Qualifier("kotakBankApiService") BankApiService kotakBankApiService,
            @Qualifier("axisBankApiService") BankApiService axisBankApiService) {
        this.hdfcBankApiService = hdfcBankApiService;
        this.iciciBankApiService = iciciBankApiService;
        this.kotakBankApiService = kotakBankApiService;
        this.axisBankApiService = axisBankApiService;
    }

    /**
     * Get bank API service based on bank provider
     * @param bankProvider The bank provider enum
     * @return BankApiService implementation for the specified bank
     */
    public BankApiService getBankApiService(BankProvider bankProvider) {
        if (bankProvider == null) {
            // Default to Axis Bank if no preference specified
            return axisBankApiService;
        }

        switch (bankProvider) {
            case HDFC:
                return hdfcBankApiService;
            case ICICI:
                return iciciBankApiService;
            case KOTAK:
                return kotakBankApiService;
            case AXIS:
            default:
                return axisBankApiService;
        }
    }

    /**
     * Get bank API service based on bank name string
     * @param bankName The bank name as string
     * @return BankApiService implementation for the specified bank
     */
    public BankApiService getBankApiService(String bankName) {
        if (bankName == null || bankName.trim().isEmpty()) {
            return axisBankApiService; // Default to Axis
        }

        switch (bankName.toUpperCase()) {
            case "HDFC":
                return hdfcBankApiService;
            case "ICICI":
                return iciciBankApiService;
            case "KOTAK":
                return kotakBankApiService;
            case "AXIS":
            default:
                return axisBankApiService;
        }
    }

    /**
     * Bank provider enum matching the one in Merchant entity
     */
    public enum BankProvider {
        HDFC("HDFC Bank"),
        ICICI("ICICI Bank"),
        KOTAK("Kotak Mahindra Bank"),
        AXIS("Axis Bank");

        private final String displayName;

        BankProvider(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() {
            return displayName;
        }
    }
}