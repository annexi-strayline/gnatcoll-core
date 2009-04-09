-----------------------------------------------------------------------
--                          G N A T C O L L                          --
--                                                                   --
--                  Copyright (C) 2008-2009, AdaCore                 --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Unchecked_Deallocation;

package body GNATCOLL.IO is

   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (File_Record'Class, File_Access);

   ---------
   -- Ref --
   ---------

   procedure Ref (File : File_Access) is
   begin
      File.Ref_Count := File.Ref_Count + 1;
   end Ref;

   -----------
   -- Unref --
   -----------

   procedure Unref (File : in out File_Access) is
   begin
      if File.Ref_Count > 0 then
         File.Ref_Count := File.Ref_Count - 1;

         if File.Ref_Count = 0 then
            Destroy (File.all);
            Unchecked_Free (File);
         end if;
      end if;
   end Unref;

   -------------
   -- Destroy --
   -------------

   procedure Destroy (File : in out File_Record) is
   begin
      Free (File.Full);
      Free (File.Normalized);
   end Destroy;

end GNATCOLL.IO;
