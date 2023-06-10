module flash_connect(
    input PI_OE,
    input PI_CS,
    input PI_SCK,
    input PI_MOSI,
    input PI_MISO_IN,
    output PI_MISO_OUT,
    output PI_MISO_OE,
    input FLASH_CS_IN,
    output FLASH_CS_OUT,
    output FLASH_CS_OE,
    input FLASH_SCK_IN,
    output FLASH_SCK_OUT,
    output FLASH_SCK_OE,
    input FLASH_MOSI_IN,
    output FLASH_MOSI_OUT,
    output FLASH_MOSI_OE,
    input FLASH_MISO
);

assign FLASH_CS_OUT = PI_CS;
assign FLASH_SCK_OUT = PI_SCK;
assign FLASH_MOSI_OUT = PI_MOSI;
assign PI_MISO_OUT = FLASH_MISO;

assign FLASH_CS_OE = PI_OE;
assign FLASH_SCK_OE = PI_OE;
assign FLASH_MOSI_OE = PI_OE;
assign PI_MISO_OE = PI_OE;

endmodule
