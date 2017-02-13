------------------------------------------------------------------------------
--                             G N A T C O L L                              --
--                                                                          --
--                     Copyright (C) 2016-2017, AdaCore                     --
--                                                                          --
-- This library is free software;  you can redistribute it and/or modify it --
-- under terms of the  GNU General Public License  as published by the Free --
-- Software  Foundation;  either version 3,  or (at your  option) any later --
-- version. This library is distributed in the hope that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
------------------------------------------------------------------------------

--  Add support for postgresql Range types.
--  These types are currently only support for postgreSQL.

with GNATCOLL.SQL_Impl;        use GNATCOLL.SQL_Impl;
with GNATCOLL.SQL.Inspect;     use GNATCOLL.SQL.Inspect;
with GNATCOLL.SQL.Exec;        use GNATCOLL.SQL.Exec;

generic
   with package Base_Fields is new Field_Types (others => <>);
   --  A range is a tuple of two instances of this type, for instance:
   --      [0.0, 10.0]
   --  or  [2010-01-01 14:30, 2010-01-01 15:30)

   SQL_Type : String;
   --  The name of the postgres type, for instance:
   --      numrange
   --  or  daterange

   Ada_SQL_Type : String := SQL_Type;
   --  The suffix of the Ada type that represents these fields. It
   --  should include package names if needed, depending on where the
   --  instance is done.

package GNATCOLL.SQL.Ranges is

   package Impl is
      type Range_Type is (Min_Unbounded, Standard, Max_Unbounded,
                          Doubly_Unbounded, Empty);
      type Ada_Range (Kind : Range_Type := Standard) is private;

      function Create_Range
         (Min, Max     : Base_Fields.Field'Class;
          Min_Included : Boolean := True;
          Max_Included : Boolean := True) return Ada_Range;
      --  A range [min,max], (min,max], (min,max) or [min,max)

      function Create_Min_Unbounded_Range
         (Max          : Base_Fields.Field'Class;
          Max_Included : Boolean := True) return Ada_Range;
      --  An unbounded range:  [,max] or [,max)

      function Create_Max_Unbounded_Range
         (Min          : Base_Fields.Field'Class;
          Min_Included : Boolean := True) return Ada_Range;
      --  An unbounded range:  [min,] or (min,]

      Doubly_Unbounded_Range : constant Ada_Range (Doubly_Unbounded);
      Empty_Range : constant Ada_Range (Empty);

      function Range_To_SQL
        (Self : Formatter'Class; Value : Ada_Range; Quote : Boolean)
        return String;
      --  Convert the Value to a string suitable for SQL queries

   private
      type Ada_Range (Kind : Range_Type := Standard) is record
         case Kind is
            when Min_Unbounded =>
               MaxU           : GNATCOLL.SQL.SQL_Field_Pointer;
               MaxU_Included  : Boolean := True;
            when Standard      =>
               Min, Max      : GNATCOLL.SQL.SQL_Field_Pointer;
               Min_Included  : Boolean := True;
               Max_Included  : Boolean := True;
            when Max_Unbounded =>
               MinU           : GNATCOLL.SQL.SQL_Field_Pointer;
               MinU_Included  : Boolean := True;
            when Doubly_Unbounded | Empty =>
               null;
         end case;
      end record;

      Doubly_Unbounded_Range : constant Ada_Range :=
         (Kind => Doubly_Unbounded);
      Empty_Range : constant Ada_Range := (Kind => Empty);
   end Impl;

   subtype Ada_Range is Impl.Ada_Range;

   Doubly_Unbounded_Range : constant Ada_Range := Impl.Doubly_Unbounded_Range;
   Empty_Range : constant Ada_Range := Impl.Empty_Range;

   function Create_Range
      (Min, Max     : Base_Fields.Field'Class;
       Min_Included : Boolean := True;
       Max_Included : Boolean := True) return Ada_Range
      renames Impl.Create_Range;
   --  The Ada representation for a range. Bounds can be inclusive or
   --  exclusive.

   function Create_Min_Unbounded_Range
      (Max          : Base_Fields.Field'Class;
       Max_Included : Boolean := True) return Ada_Range
      renames Impl.Create_Min_Unbounded_Range;
   --  An unbounded range:  [,max] or [,max)

   function Create_Max_Unbounded_Range
      (Min          : Base_Fields.Field'Class;
       Min_Included : Boolean := True) return Ada_Range
      renames Impl.Create_Max_Unbounded_Range;
   --  An unbounded range:  [min,] or (min,]

   type SQL_Parameter_Range is
      new GNATCOLL.SQL_Impl.SQL_Parameter_Text with null record;

   overriding function Type_String
     (Self   : SQL_Parameter_Range;
      Index  : Positive;
      Format : Formatter'Class) return String
     is (Format.Parameter_String (Index, SQL_Type));
   --  Describe the type of the parameter to the database.

   type Field_Type_Range is
      new GNATCOLL.SQL.Inspect.Field_Type with null record;

   overriding function Type_To_SQL
     (Self         : Field_Type_Range;
      Format       : access Formatter'Class := null;
      For_Database : Boolean := True) return String
     is (if For_Database then SQL_Type else Ada_SQL_Type);
   --  Encoding for the type in the schema description

   overriding function Type_From_SQL
     (Self : in out Field_Type_Range; Str : String) return Boolean
     is (Str = SQL_Type);
   --  Recognize the type in the schema description

   overriding function Parameter_Type
     (Self : Field_Type_Range) return SQL_Parameter_Type'Class
     is (SQL_Parameter_Range'(others => <>));
   --  To later encode the field in a query, as a parameter (?1, $1::range,...)

   package Range_Fields is new Field_Types
     (Ada_Type    => Ada_Range,
      To_SQL      => Impl.Range_To_SQL,
      Param_Type  => SQL_Parameter_Range);

   type SQL_Field_Range is new Range_Fields.Field with null record;
   Null_Field_Range : constant SQL_Field_Range;

   function Range_Param (Index : Positive) return Range_Fields.Field'Class
     renames Range_Fields.Param;
   --  A field whose value will be provided independently when executing the
   --  query.

   function Range_Value
     (Self  : Forward_Cursor'Class; Field : Field_Index) return Ada_Range;
   --  Retrieve a range value from the output of a SQL query

   Str_Contains          : aliased constant String := "@>";
   Str_Is_Contained      : aliased constant String := "<@";
   Str_Left_Of           : aliased constant String := "<<";
   Str_Right_Of          : aliased constant String := ">>";
   Str_Not_Extend_Right  : aliased constant String := "&<";
   Str_Not_Extend_Left   : aliased constant String := "&>";
   Str_Adjacent          : aliased constant String := "-|-";
   Str_Overlap           : aliased constant String := "&&";
   Str_Is_Empty          : aliased constant String := "isempty(";
   Str_Close_Parenthesis : aliased constant String := ")";

   function Contains (R1, R2 : SQL_Field_Range) return SQL_Criteria
      is (Compare (R1, R2, Str_Contains'Access));
   function Contains (R : SQL_Field_Range; V : Ada_Range) return SQL_Criteria
      is (Compare (R, Range_Fields.Expression (V), Str_Contains'Access));
   --  For instance:  [2,4] @> [2,3]  => true

   function Is_Contained (R1, R2 : SQL_Field_Range) return SQL_Criteria
      is (Compare (R1, R2, Str_Is_Contained'Access));
   function Is_Contained
      (V : Ada_Range; R : SQL_Field_Range) return SQL_Criteria
      is (Compare (Range_Fields.Expression (V), R, Str_Is_Contained'Access));
   --  For instance:  [2,4] <@  [1,7]  => true

   function Overlap (R1, R2 : SQL_Field_Range) return SQL_Criteria
      is (Compare (R1, R2, Str_Overlap'Access));
   --  For instance:  [3,7] && [4,12]  => true

   function Strictly_Left_Of (R1, R2 : SQL_Field_Range) return SQL_Criteria
      is (Compare (R1, R2, Str_Left_Of'Access));
   --  For instance: [1,10] << [100,110]   => true

   function Strictly_Right_Of (R1, R2 : SQL_Field_Range) return SQL_Criteria
      is (Compare (R1, R2, Str_Right_Of'Access));
   --  For instance: [50,60] >> [20,30]  => true

   function Not_Extend_To_Right_Of
      (R1, R2 : SQL_Field_Range) return SQL_Criteria
      is (Compare (R1, R2, Str_Not_Extend_Right'Access));
   --  For instance: [1,20] &< [18,20]  => true

   function Not_Extend_To_Left_Of
      (R1, R2 : SQL_Field_Range) return SQL_Criteria
      is (Compare (R1, R2, Str_Not_Extend_Left'Access));
   --  For instance: [7,20] &> [5,10]  => true

   function Adjacent_To (R1, R2 : SQL_Field_Range) return SQL_Criteria
      is (Compare (R1, R2, Str_Adjacent'Access));
   --  For instance: [1.1, 2.2]  -|-  [2.2, 3.3]  => true

   function Union is new Range_Fields.Operator ("+");
   --  For instance, [5,15] + [10,20] = [5,20]

   function Intersection is new Range_Fields.Operator ("*");
   --  For instance, [5,15] * [10,20] = [10,15]

   function Difference is new Range_Fields.Operator ("-");
   --  For instance, [5,15] - [10,20] = [5,10]

   function Is_Empty (R1 : SQL_Field_Range) return SQL_Criteria
     is (Compare1 (R1, Str_Is_Empty'Access, Str_Close_Parenthesis'Access));
   --  isempty(R1)

   function Merge is new Range_Fields.Apply_Function2
      (Argument1_Type => SQL_Field_Range,
       Argument2_Type => SQL_Field_Range,
       Name           => "range_merge(");
   --  The smallest range which includes both arguments
   --  For instance:  range_merge([1,2], [3,4])  = [1,4]

   function Lower is new Base_Fields.Apply_Function
     (Argument_Type => SQL_Field_Range,
      Name          => "lower(");
   --  Lower bound of the range

   function Upper is new Base_Fields.Apply_Function
     (Argument_Type => SQL_Field_Range,
      Name          => "upper(");
   --  Upper bound of the range

private
   Null_Field_Range : constant SQL_Field_Range :=
     (Range_Fields.Null_Field with null record);
end GNATCOLL.SQL.Ranges;
