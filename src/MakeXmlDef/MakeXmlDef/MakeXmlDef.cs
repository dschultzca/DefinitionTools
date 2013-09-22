/*
 * Copyright (C) 2013  Dale C. Schultz
 * RomRaider member ID: dschultz
 *
 * You are free to use this source for any purpose, but please keep
 * notice of where it came from!
 */
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Xml;
using System.Xml.XPath;
using System.Text.RegularExpressions;

namespace MakeXmlDef
{
    class MakeXmlDef
    {
        private static Hashtable addrTable = new Hashtable();
        private static Hashtable sizexTable = new Hashtable();
        private static Hashtable sizeyTable = new Hashtable();
        private static HashSet<string> names = new HashSet<string>();

        static void Main(string[] args)
        {
            if (args.Length == 0)
            {
                Usage();
                return;
            }

            // read the address file into a hash table for key lookups on table/axis name
            string line;
            try
            {
                StreamReader file = new StreamReader(args[1]);
                string pattern = @"\s+";
                while ((line = file.ReadLine()) != null)
                {
                    string[] result = Regex.Split(line, pattern);
                    if (result.Length == 4 && !addrTable.Contains(result[0])) // 3D Table with X & Y size
                    {
                        addrTable.Add(result[0], result[1]);
                        sizexTable.Add(result[0], result[2]);
                        sizeyTable.Add(result[0], result[3]);
                    }
                    if (result.Length == 3 && !addrTable.Contains(result[0])) // 2D Table with Y size
                    {
                        addrTable.Add(result[0], result[1]);
                        sizeyTable.Add(result[0], result[2]);
                    }
                    if (result.Length == 2 && !addrTable.Contains(result[0])) // 1D Table no size
                    {
                        addrTable.Add(result[0], result[1]);
                    }
                }
                file.Close();
            }
            catch (Exception e)
            {
                Console.WriteLine("Could not read address file. " + e);
                return;
            }
            if (addrTable.Count == 0)
            {
                Console.WriteLine("The address file " + args[1] + "contained no valid entries.");
                return;
            }

            XmlDocument doc = new XmlDocument();
            try
            {
                doc.Load(args[0]);
            }
            catch (Exception e)
            {
                Console.WriteLine("Could not read template file. " + e);
                return;
            }

            string path = "/roms/rom/table";
            XmlNodeList nodeList = doc.SelectNodes(path); // all table Nodes of the template file
            Console.WriteLine("Table size change summary (changes over base):");

            foreach (XmlNode node in nodeList)
            {
                if ((node.NodeType == XmlNodeType.Element) && node.Name == "table")
                {
                    XmlAttributeCollection attrList = node.Attributes; // attributes of current table element
                    string name = attrList["name"].Value; // table name which will be "cleaned" to match IDA names
                    string rawName = name;                // table name from table element
                    name = ConvertName(name);             // convert the name to match IDA names
                    string storageAddress = "undef";
                    if (addrTable.Contains(name) && attrList["storageaddress"] != null)
                    {
                        storageAddress = addrTable[name].ToString();
						attrList["storageaddress"].Value = Convert.ToInt32(storageAddress , 16).ToString("X");
                        //Console.WriteLine(name + " = " + attrList["storageaddress"].Value);

                        string path1 = "/roms/rom/table[@name='" + rawName + "']";
                        XmlNodeList tableList = doc.SelectNodes(path1); // all table nodes of template file that match this rawName
                        //Console.WriteLine("Search for: " + path1 + " found: " + tableList.Count);
                        foreach (XmlNode tableNode in tableList)
                        {
                            if ((tableNode.NodeType == XmlNodeType.Element) && tableNode.Name == "table")
                            {
                                string status = "Updated";
                                XmlAttributeCollection tableAttrList = tableNode.Attributes;
                                if (tableAttrList["storageaddress"] == null &&  // this is the entry in the 32BITBASE rom section
                                    tableAttrList["sizex"] != null &&
                                    sizexTable.Contains(name)
                                   )
                                {
                                    // Is the default X size different than the IDA table X size
                                    if (tableAttrList["sizex"].Value != sizexTable[name].ToString()) // yes
                                    {
                                        // Is there an X size attribute in our template
                                        if (attrList["sizex"] == null) // no
                                        {
                                            XmlAttribute newAttr = doc.CreateAttribute("sizex");
                                            newAttr.Value = sizexTable[name].ToString();
                                            node.Attributes.Append(newAttr);
                                            status = "Added  ";
                                        }
                                        else // yes
                                        {
                                            attrList["sizex"].Value = sizexTable[name].ToString();
                                        }
                                        Console.WriteLine(
                                            string.Format("{3} X size: {0,2} -> {1,2} Table Name: '{2}'", tableAttrList["sizex"].Value, sizexTable[name].ToString(), tableAttrList["name"].Value, status)
                                        );
                                    }
                                    else // no
                                    {
                                        // Is there an X size attribute in our template
                                        if (attrList["sizex"] != null) // yes
                                        {
                                            // remove the unneeded attribute
                                            status = "Removed";
                                            Console.WriteLine(
                                                string.Format("{2} X size: {1,2} from  Table Name: '{0}'", tableAttrList["name"].Value, attrList["sizex"].Value, status)
                                            );
                                            node.Attributes.Remove(attrList["sizex"]);
                                        }
                                    }
                                }
                                // Is the default Y size different than the IDA table Y size
                                if (tableAttrList["storageaddress"] == null &&
                                    tableAttrList["sizey"] != null &&
                                    sizeyTable.Contains(name)
                                   )
                                {
                                    if (tableAttrList["sizey"].Value != sizeyTable[name].ToString())
                                    {
                                        if (attrList["sizey"] == null)
                                        {
                                            XmlAttribute newAttr = doc.CreateAttribute("sizey");
                                            newAttr.Value = sizeyTable[name].ToString();
                                            node.Attributes.Append(newAttr);
                                            status = "Added  ";
                                        }
                                        else
                                        {
                                            attrList["sizey"].Value = sizeyTable[name].ToString();
                                        }
                                        Console.WriteLine(
                                            string.Format("{3} Y size: {0,2} -> {1,2} Table Name: '{2}'", tableAttrList["sizey"].Value, sizeyTable[name].ToString(), tableAttrList["name"].Value, status)
                                        );
                                    }
                                    else
                                    {
                                        // Is there an Y size attribute in our template
                                        if (attrList["sizey"] != null) // yes
                                        {
                                            // remove the unneeded attribute
                                            status = "Removed";
                                            Console.WriteLine(
                                                string.Format("{2} Y size: {1,2} from  Table Name: '{0}'", tableAttrList["name"].Value, attrList["sizey"].Value, status)
                                            );
                                            node.Attributes.Remove(attrList["sizey"]);
                                        }
                                    }
                                }
                            }
                        }
                        if (node.HasChildNodes) // thesee are the axis entries for the current table element
                        {
                            XmlNodeList childNodes = node.ChildNodes;
                            foreach (XmlNode child in childNodes)
                            {
                                if ((child.NodeType == XmlNodeType.Element) && child.Name == "table")
                                {
                                    XmlAttributeCollection cattrList = child.Attributes;
                                    string axis = cattrList["type"].Value;
                                    axis = ConvertName(name + "_" + axis);
                                    if (addrTable.Contains(axis))
                                    {
										cattrList["storageaddress"].Value = Convert.ToInt32(addrTable[axis].ToString() , 16).ToString("X");
                                    }
                                    //Console.WriteLine(axis + " = " + cattrList["storageaddress"].Value);
                                }
                            }
                        }
                    }
                }
            }
            try
            {
                doc.Save(args[2]);
            }
            catch (Exception e)
            {
                Console.WriteLine("Could not write output file. " + e);
                return;
            }
        }

        private static string ConvertName(string original)
        {
            original = original.Replace(")(", "_");

            StringBuilder builder = new StringBuilder(original.Length);
            foreach (char c in original)
            {
                if (char.IsLetterOrDigit(c))
                {
                    builder.Append(c);
                    continue;
                }

                if (c == '_')
                {
                    builder.Append(c);
                    continue;
                }

                if (char.IsWhiteSpace(c))
                {
                    builder.Append('_');
                    continue;
                }

                if (c == '*')
                {
                    builder.Append("Ext");
                    continue;
                }
            }

            // Make sure the name is unique
            string name = builder.ToString();
            while (names.Contains(name))
            {
                name = name + "_";
            }
            names.Add(name);

            return name;
        }

        private static void Usage()
        {
            Console.WriteLine("MakeXmlDef Usage:");
            Console.WriteLine("MakeXmlDef.exe <XML-template> <IDA-addresses> <output-file>");
            Console.WriteLine();
            Console.WriteLine("Where <XML-template>  is an XML file that will be used as a template to modify.");
            Console.WriteLine("      <IDA-addresses> is a text file containing Table names and Addresses from");
            Console.WriteLine("                      the IDA Names Window.");
            Console.WriteLine("      <output-file>   is the file to save the output to.");
        }
    }
}
