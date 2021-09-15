library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_en : out std_logic;
        o_we : out std_logic;
        o_data : out std_logic_vector (7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    type state is (reset, start, first_read, comp_dim_and_ofl, comp_min_max, second_read, delta, delta2, shift, temp, create_new_value, write, done);
    signal next_o_done, next_o_en, next_o_we : std_logic := '0';
    signal next_o_data: std_logic_vector(7 downto 0) := "00000000";
    signal next_o_address : std_logic_vector(15 downto 0) := "0000000000000000";
    signal current_address, next_address: std_logic_vector(15 downto 0) := "0000000000000000";
    signal current_data, next_current_data : std_logic_vector(7 downto 0);
    signal current_state, next_state: state;
    signal max, min: std_logic_vector(7 downto 0):= "00000000";
    signal next_min: std_logic_vector(7 downto 0):= "11111111";
    signal next_max: std_logic_vector(7 downto 0):= "00000000";
    signal ofl, next_ofl: std_logic_vector(15 downto 0); --potrebbe essere necessario inizializzarle
    signal columns_number, rows_number: std_logic_vector(7 downto 0); --potrebbe essere necessario inizializzarli
    
    signal shift_value : integer range 8 downto 0;
    signal temp_out, next_temp_out: std_logic_vector(8 downto 0);
    signal shift_register: std_logic_vector(15 downto 0) := "0000000000000000";
    signal address_to_write, next_address_to_write: std_logic_vector(15 downto 0):="0000000000000000";
begin
    memory: process(i_clk, i_rst)
     begin
       if (i_clk'event and i_clk = '1') then
         if (i_rst = '1') then
            next_state <= reset;
            
         else
            current_state <= next_state;
            o_done <= next_o_done;
            o_en <= next_o_en;
            o_we <= next_o_we;
            o_data <= next_o_data;
            o_address <= next_o_address;

            current_address <= next_address;
            current_data <= next_current_data; 
            temp_out <= next_temp_out;
            ofl <= next_ofl;
            min<=next_min;
            max<=next_max;
            address_to_write <= next_address_to_write;
         end if;
         case current_state is
            when reset =>
                next_state <= start;
            when start =>
                -- tutti i signal di supporto devono andare a 0
                current_address <= "0000000000000000";
                next_address <= "0000000000000000";
                current_data <= "00000000";
                next_current_data <= "00000000";
                next_o_address <= "0000000000000000";
                min <= "11111111";
                next_min <= "11111111";
                max <= "00000000";
                next_max <= "00000000";
                ofl <= "0000000000000000";
                next_ofl <= "0000000000000000";
                address_to_write <= "0000000000000000";
                next_address_to_write <= "0000000000000000";
                
                if i_start = '0' then
                    next_state <= start;
                    next_o_we <= '0';
                    next_o_en <= '0';
                else
                    next_state <= first_read;
                    next_current_data <= i_data;
                    next_o_address <= "0000000000000000";
                    next_o_en <= '1';
                    next_o_we <= '0';
                end if;
            when first_read =>
                if(current_address = 0) then
                    columns_number <= i_data;
                    next_state <= first_read;
                else
                    rows_number <= i_data;
                    next_state <= comp_dim_and_ofl;   
                end if;
                next_address<=current_address+1;
                next_o_address <= current_address+1;
                next_o_en <= '1';
                next_o_we <= '0';
           when comp_dim_and_ofl =>
                next_ofl <= std_logic_vector((UNSIGNED(rows_number)*UNSIGNED(columns_number))+2);
                next_address_to_write <= std_logic_vector((UNSIGNED(rows_number)*UNSIGNED(columns_number))+2);
                next_o_en <= '1';
                next_o_we <= '0';                
                next_state <= comp_min_max;
                next_address <= "0000000000000010";
                next_o_address <= "0000000000000010";
           when comp_min_max =>
                if(current_address=ofl) then
                    next_address <= "0000000000000010";
                    next_o_address <= "0000000000000010";
                    next_state <= second_read;
                else
                    if(i_data<min) then
                        next_min <= i_data;
                    else
                        next_min<=min;
                    end if;
                    if(i_data>max) then
                        next_max <= i_data;
                    else
                        next_max<=max;
                    end if;
                    next_address <= current_address+1;
                    next_o_address <= current_address+1;
                    next_state <= comp_min_max;
                end if;
                next_o_en <= '1';
                next_o_we <= '0';
           when second_read =>
                if current_address = ofl then
                    next_state <= done;
                    next_o_done <= '1';
                    next_o_we <= '0';
                    next_o_en <= '0';
                else
                    next_o_address <= current_address;
                    next_state <= delta;
                    next_o_done <= '0';
                    next_o_we <= '0';
                    next_o_en <= '1';
                end if;
           when delta =>
                if min = "00000000" then
                  next_temp_out <= '0' & std_logic_vector(unsigned(max));
                else
                  next_temp_out <= '0' & std_logic_vector(unsigned(max) - unsigned(min));
                end if;
                
                next_state <= delta2;
                next_o_en<= '1';
                next_o_we<= '0';
           when delta2 =>
               if(temp_out = "011111111") then
                    next_temp_out <= "100000000";
                else
                    next_temp_out <= '0' & std_logic_vector(unsigned(max) - unsigned(min)+1);
                end if;
                next_state <= shift;
                next_o_en<='1';
                next_o_we<= '0';
           when shift =>
                if temp_out(8) = '1' then
                    shift_value <= 0;
                elsif (temp_out(7)='1') then
                    shift_value <= 1;
                elsif(temp_out(6)='1') then
                    shift_value <= 2;
                elsif(temp_out(5)='1') then
                    shift_value <= 3;
                elsif(temp_out(4)='1') then
                    shift_value <= 4;
                elsif(temp_out(3)='1') then
                    shift_value <= 5;
                elsif(temp_out(2)='1') then
                    shift_value <= 6;
               elsif(temp_out(1)='1') then
                    shift_value <= 7;
               else
                    shift_value <= 8;
               end if;
               next_temp_out <= '0' & std_logic_vector(unsigned(i_data) - unsigned(min));
               next_state <= temp;
               next_o_we <= '0';
               next_o_en <= '1';
           when temp =>
                if(shift_value = 0) then
                    shift_register <= "0000000" & temp_out;
                else
                    shift_register <= std_logic_vector(shift_left(unsigned("0000000" & temp_out), natural(shift_value)));
                end if;
                next_o_we <= '0';
                next_o_en <= '1';
                next_o_done <= '0';
                
                next_state <= create_new_value;
           when create_new_value =>
                if(shift_register > "0000000011111111") then
                    next_o_data <= "11111111";
                else
                    next_o_data <= shift_register(7 downto 0);
                end if;
                next_address <= current_address+1;
                next_o_address <= address_to_write;
                next_address_to_write <= address_to_write + 1;
                next_o_done <= '0';
                next_o_en <= '1';
                next_o_we <= '1';
                
                next_state <= write;
           when write =>
                next_o_done <= '0';
                next_o_en <= '0';
                next_o_we <= '0';
                
                next_state <= second_read;
           when done =>
                if (i_start = '0') then
                    next_o_done <= '0';
                    next_state<=start;
                else
                    next_state <= done;
                end if;
        end case;
       end if; 
     end process;
end Behavioral;