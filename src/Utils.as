class Utils
{
	public static function Contains(array:Array, target):Boolean
	{
		for (var i:Number = 0 ; i < array.length ; i++)
		{
			if (array[i] == target)
			{
				return true;
			}
		}
		
		return false;
	}
	
}